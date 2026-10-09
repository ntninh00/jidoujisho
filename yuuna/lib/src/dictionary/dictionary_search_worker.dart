import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';

/// What a dictionary search found, before it is stored. Small enough to send
/// between isolates.
class DictionarySearchOutcome {
  /// Describe what a search found.
  DictionarySearchOutcome({
    required this.searchTerm,
    required this.bestLength,
    required this.headingIds,
  });

  /// The search term after language-specific clean up.
  final String searchTerm;

  /// Length of the longest part of the search term that matched.
  final int bestLength;

  /// Ids of the headings to show, in display order.
  final List<int> headingIds;
}

/// The language-specific search run inside the worker isolate.
typedef DictionarySearchFunction = Future<DictionarySearchOutcome?> Function(
    DictionarySearchParams params);

/// A search answered by the worker. [persisted] completes with the id of the
/// stored result once it has been written for search history, or null if it
/// was not stored.
class DictionarySearchReply {
  /// Pair a search outcome with its pending storage.
  DictionarySearchReply({
    required this.outcome,
    required this.persisted,
  });

  /// What the search found, or null if nothing matched.
  final DictionarySearchOutcome? outcome;

  /// Completes once the result is stored.
  final Future<int?> persisted;
}

class _Job {
  _Job({
    required this.id,
    required this.function,
    required this.params,
    required this.channel,
    required this.persist,
  });

  final int id;
  final DictionarySearchFunction function;
  final DictionarySearchParams params;
  final String? channel;
  final bool persist;
  final Completer<DictionarySearchReply?> reply = Completer();
  final Completer<int?> persisted = Completer();
}

/// Runs dictionary searches on one long-lived isolate that keeps the database
/// open, instead of starting an isolate and opening the database on every
/// lookup.
///
/// Jobs run one at a time. A new job on a named channel replaces a queued,
/// not yet started job on the same channel; the replaced job resolves to null.
/// This keeps fast tapping or typing from building a backlog.
class DictionarySearchWorker {
  DictionarySearchWorker._();

  /// The shared worker.
  static final DictionarySearchWorker instance = DictionarySearchWorker._();

  SendPort? _sendPort;
  Completer<SendPort>? _starting;
  ReceivePort? _receivePort;
  int _nextId = 0;
  _Job? _running;
  final Queue<_Job> _queue = Queue();

  /// Search with [function] on the worker isolate. Resolves to null when a
  /// newer job on the same [channel] replaced this one before it started.
  /// Without [persist], the result is not stored, and its reply's
  /// [DictionarySearchReply.persisted] is null: storing takes longer than
  /// most searches, and typing would wait on it for every key.
  Future<DictionarySearchReply?> search({
    required DictionarySearchFunction function,
    required DictionarySearchParams params,
    String? channel,
    bool persist = true,
  }) {
    _Job job = _Job(
      id: _nextId++,
      function: function,
      params: params,
      channel: channel,
      persist: persist,
    );

    if (channel != null) {
      _queue.removeWhere((queued) {
        if (queued.channel == channel) {
          queued.reply.complete(null);
          queued.persisted.complete(null);
          return true;
        }
        return false;
      });
    }

    _queue.add(job);
    _pump();
    return job.reply.future;
  }

  Future<SendPort> _ensureStarted() {
    if (_sendPort != null) {
      return SynchronousFuture(_sendPort!);
    }
    if (_starting != null) {
      return _starting!.future;
    }

    Completer<SendPort> starting = Completer();
    _starting = starting;
    ReceivePort receivePort = ReceivePort();
    _receivePort = receivePort;
    receivePort.listen(_onMessage);
    Isolate.spawn(_workerMain, receivePort.sendPort, debugName: 'dictionary')
        .catchError((error) {
      _starting = null;
      if (!starting.isCompleted) {
        starting.completeError(error);
      }
      return Isolate.current;
    });
    return starting.future;
  }

  void _pump() async {
    if (_running != null || _queue.isEmpty) {
      return;
    }

    _Job job = _queue.removeFirst();
    _running = job;
    try {
      SendPort port = await _ensureStarted();
      port.send(<Object?>[job.id, job.function, job.params, job.persist]);
    } catch (error) {
      _running = null;
      job.reply.completeError(error);
      job.persisted.complete(null);
      _pump();
    }
  }

  void _onMessage(Object? message) {
    if (message is SendPort) {
      _sendPort = message;
      _starting?.complete(message);
      _starting = null;
      return;
    }

    if (message is! List || message.length != 3) {
      return;
    }

    int id = message[0] as int;
    String kind = message[1] as String;
    Object? payload = message[2];

    _Job? job = _running;
    if (job == null || job.id != id) {
      return;
    }

    switch (kind) {
      case 'result':
        job.reply.complete(
          DictionarySearchReply(
            outcome: payload as DictionarySearchOutcome?,
            persisted: job.persisted.future,
          ),
        );
        break;
      case 'error':
        job.reply.completeError(StateError(payload.toString()));
        job.persisted.complete(null);
        _running = null;
        _pump();
        break;
      case 'persisted':
        if (!job.persisted.isCompleted) {
          job.persisted.complete(payload as int?);
        }
        _running = null;
        _pump();
        break;
    }
  }

  /// Stop the worker. The next search starts a new one.
  void shutdown() {
    _receivePort?.close();
    _receivePort = null;
    _sendPort = null;
    _starting = null;
  }
}

/// Entry point of the worker isolate.
@pragma('vm:entry-point')
Future<void> _workerMain(SendPort mainPort) async {
  ReceivePort port = ReceivePort();
  mainPort.send(port.sendPort);

  await for (Object? message in port) {
    if (message is! List || message.length != 4) {
      continue;
    }

    int id = message[0] as int;
    DictionarySearchFunction function = message[1] as DictionarySearchFunction;
    DictionarySearchParams params = message[2] as DictionarySearchParams;
    bool persist = message[3] as bool;

    DictionarySearchOutcome? outcome;
    try {
      outcome = await function(params);

      /// Words the user defined come first.
      Isar? database = Isar.getInstance();
      if (outcome != null && database != null) {
        outcome = DictionarySearchOutcome(
          searchTerm: outcome.searchTerm,
          bestLength: outcome.bestLength,
          headingIds: MyWords.putFirst(database, outcome.headingIds),
        );
      }
    } catch (error, stack) {
      mainPort.send(<Object?>[id, 'error', '$error\n$stack']);
      continue;
    }

    /// Answer first so the popup can show, then store for search history.
    mainPort.send(<Object?>[id, 'result', outcome]);

    int? resultId;
    if (outcome != null && persist) {
      try {
        Isar database = Isar.getInstance() ??
            await Isar.open(
              globalSchemas,
              directory: params.directoryPath,
              maxSizeMiB: 8192,
            );
        resultId = persistSearchOutcome(
          database: database,
          outcome: outcome,
          maximumStoredResults: params.maximumDictionarySearchResults,
        );
      } catch (error) {
        debugPrint('Could not store search result: $error');
      }
    }
    mainPort.send(<Object?>[id, 'persisted', resultId]);
  }
}
