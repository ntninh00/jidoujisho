/// Generated file. Do not edit.
///
/// Locales: 2
/// Strings: 1694 (847 per locale)
///
/// Built on 2026-10-07 at 06:13 UTC

// coverage:ignore-file
// ignore_for_file: type=lint

import 'package:flutter/widgets.dart';
import 'package:slang/builder/model/node.dart';
import 'package:slang_flutter/slang_flutter.dart';
export 'package:slang_flutter/slang_flutter.dart';

const AppLocale _baseLocale = AppLocale.en;

/// Supported locales, see extension methods below.
///
/// Usage:
/// - LocaleSettings.setLocale(AppLocale.en) // set locale
/// - Locale locale = AppLocale.en.flutterLocale // get flutter locale from enum
/// - if (LocaleSettings.currentLocale == AppLocale.en) // locale check
enum AppLocale with BaseAppLocale<AppLocale, _StringsEn> {
	en(languageCode: 'en', build: _StringsEn.build),
	vi(languageCode: 'vi', build: _StringsVi.build);

	const AppLocale({required this.languageCode, this.scriptCode, this.countryCode, required this.build}); // ignore: unused_element

	@override final String languageCode;
	@override final String? scriptCode;
	@override final String? countryCode;
	@override final TranslationBuilder<AppLocale, _StringsEn> build;

	/// Gets current instance managed by [LocaleSettings].
	_StringsEn get translations => LocaleSettings.instance.translationMap[this]!;
}

/// Method A: Simple
///
/// No rebuild after locale change.
/// Translation happens during initialization of the widget (call of t).
/// Configurable via 'translate_var'.
///
/// Usage:
/// String a = t.someKey.anotherKey;
/// String b = t['someKey.anotherKey']; // Only for edge cases!
_StringsEn get t => LocaleSettings.instance.currentTranslations;

/// Method B: Advanced
///
/// All widgets using this method will trigger a rebuild when locale changes.
/// Use this if you have e.g. a settings page where the user can select the locale during runtime.
///
/// Step 1:
/// wrap your App with
/// TranslationProvider(
/// 	child: MyApp()
/// );
///
/// Step 2:
/// final t = Translations.of(context); // Get t variable.
/// String a = t.someKey.anotherKey; // Use t variable.
/// String b = t['someKey.anotherKey']; // Only for edge cases!
class Translations {
	Translations._(); // no constructor

	static _StringsEn of(BuildContext context) => InheritedLocaleData.of<AppLocale, _StringsEn>(context).translations;
}

/// The provider for method B
class TranslationProvider extends BaseTranslationProvider<AppLocale, _StringsEn> {
	TranslationProvider({required super.child}) : super(settings: LocaleSettings.instance);

	static InheritedLocaleData<AppLocale, _StringsEn> of(BuildContext context) => InheritedLocaleData.of<AppLocale, _StringsEn>(context);
}

/// Method B shorthand via [BuildContext] extension method.
/// Configurable via 'translate_var'.
///
/// Usage (e.g. in a widget's build method):
/// context.t.someKey.anotherKey
extension BuildContextTranslationsExtension on BuildContext {
	_StringsEn get t => TranslationProvider.of(this).translations;
}

/// Manages all translation instances and the current locale
class LocaleSettings extends BaseFlutterLocaleSettings<AppLocale, _StringsEn> {
	LocaleSettings._() : super(utils: AppLocaleUtils.instance);

	static final instance = LocaleSettings._();

	// static aliases (checkout base methods for documentation)
	static AppLocale get currentLocale => instance.currentLocale;
	static Stream<AppLocale> getLocaleStream() => instance.getLocaleStream();
	static AppLocale setLocale(AppLocale locale, {bool? listenToDeviceLocale = false}) => instance.setLocale(locale, listenToDeviceLocale: listenToDeviceLocale);
	static AppLocale setLocaleRaw(String rawLocale, {bool? listenToDeviceLocale = false}) => instance.setLocaleRaw(rawLocale, listenToDeviceLocale: listenToDeviceLocale);
	static AppLocale useDeviceLocale() => instance.useDeviceLocale();
	@Deprecated('Use [AppLocaleUtils.supportedLocales]') static List<Locale> get supportedLocales => instance.supportedLocales;
	@Deprecated('Use [AppLocaleUtils.supportedLocalesRaw]') static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
	static void setPluralResolver({String? language, AppLocale? locale, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver}) => instance.setPluralResolver(
		language: language,
		locale: locale,
		cardinalResolver: cardinalResolver,
		ordinalResolver: ordinalResolver,
	);
}

/// Provides utility functions without any side effects.
class AppLocaleUtils extends BaseAppLocaleUtils<AppLocale, _StringsEn> {
	AppLocaleUtils._() : super(baseLocale: _baseLocale, locales: AppLocale.values);

	static final instance = AppLocaleUtils._();

	// static aliases (checkout base methods for documentation)
	static AppLocale parse(String rawLocale) => instance.parse(rawLocale);
	static AppLocale parseLocaleParts({required String languageCode, String? scriptCode, String? countryCode}) => instance.parseLocaleParts(languageCode: languageCode, scriptCode: scriptCode, countryCode: countryCode);
	static AppLocale findDeviceLocale() => instance.findDeviceLocale();
	static List<Locale> get supportedLocales => instance.supportedLocales;
	static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
}

// translations

// Path: <root>
class _StringsEn implements BaseTranslations<AppLocale, _StringsEn> {

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_StringsEn.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, _StringsEn> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final _StringsEn _root = this; // ignore: unused_field

	// Translations
	String get dictionary_media_type => 'Dictionary';
	String get player_media_type => 'Player';
	String get reader_media_type => 'Reader';
	String get viewer_media_type => 'Viewer';
	String get back => 'Back';
	String get search => 'Search';
	String get search_ellipsis => 'Search...';
	String get show_more => 'Show More';
	String get show_menu => 'Show Menu';
	String get stash => 'Stash';
	String get pick_image => 'Pick Image';
	String get undo => 'Undo';
	String get copy => 'Copy';
	String get clear => 'Clear';
	String get creator => 'Creator';
	String get share => 'Share';
	String get resume_last_media => 'Resume Last Media';
	String get change_source => 'Change Source';
	String get launch_source => 'Launch Source';
	String get card_creator => 'Card Creator';
	String get target_language => 'Target language';
	String get show_options => 'Show Options';
	String get switch_profiles => 'Switch Profiles';
	String get dictionaries => 'Dictionaries';
	String get enhancements => 'Enhancements';
	String get app_locale => 'App locale';
	String get app_locale_warning => 'Community addons and enhancements are managed by their respective developers, and these may appear in their original language.';
	String get dialog_play => 'PLAY';
	String get dialog_read => 'READ';
	String get dialog_view => 'VIEW';
	String get dialog_edit => 'EDIT';
	String get dialog_export => 'EXPORT';
	String get dialog_import => 'IMPORT';
	String get dialog_close => 'CLOSE';
	String get dialog_clear => 'CLEAR';
	String get dialog_create => 'CREATE';
	String get dialog_delete => 'DELETE';
	String get dialog_cancel => 'CANCEL';
	String get dialog_select => 'SELECT';
	String get dialog_stash => 'STASH';
	String get dialog_search => 'SEARCH';
	String get dialog_exit => 'EXIT';
	String get dialog_share => 'SHARE';
	String get dialog_pop => 'POP';
	String get dialog_save => 'SAVE';
	String get dialog_set => 'SET';
	String get dialog_browse => 'BROWSE';
	String get dialog_channel => 'CHANNEL';
	String get dialog_directory => 'DIRECTORY';
	String get dialog_crop => 'CROP';
	String get dialog_connect => 'CONNECT';
	String get dialog_append => 'APPEND';
	String get dialog_record => 'RECORD';
	String get dialog_manage => 'MANAGE';
	String get dialog_stop => 'STOP';
	String get dialog_done => 'DONE';
	String get reset => 'Reset';
	String get dialog_launch_ankidroid => 'LAUNCH ANKIDROID';
	String get media_item_delete_confirmation => 'This will clear this item from history. Are you sure you want to do this?';
	String get dictionaries_delete_confirmation => 'Deleting a dictionary will also clear all dictionary results from history. Are you sure you want to do this?';
	String get mappings_delete_confirmation => 'This profile will be deleted. Are you sure you want to do this?';
	String get catalog_delete_confirmation => 'This catalog will be deleted. Are you sure you want to do this?';
	String get dictionaries_deleting_data => 'Deleting dictionary data...';
	String get dictionaries_menu_empty => 'Import a dictionary for use';
	String get options_theme_light => 'Use light theme';
	String get options_theme_dark => 'Use dark theme';
	String get options_incognito_on => 'Turn on incognito mode';
	String get options_incognito_off => 'Turn off incognito mode';
	String get options_dictionaries => 'Manage dictionaries';
	String get options_profiles => 'Export profiles';
	String get options_enhancements => 'User enhancements';
	String get options_language => 'Language settings';
	String get options_github => 'View repository on GitHub';
	String get options_attribution => 'Licenses and attribution';
	String get options_copy => 'Copy';
	String get options_collapse => 'Collapse';
	String get options_expand => 'Expand';
	String get options_delete => 'Delete';
	String get options_show => 'Show';
	String get options_hide => 'Hide';
	String get options_edit => 'Edit';
	String get info_empty_home_tab => 'History is empty';
	String get delete_in_progress => 'Delete in progress';
	String get import_format => 'Import format';
	String get import_in_progress => 'Import in progress';
	String get import_start => 'Preparing for import...';
	String get import_clean => 'Cleaning working space...';
	String import_extract_count({required Object n}) => 'Extracted ${n} files...';
	String get import_extract => 'Extracting files...';
	String import_name({required Object name}) => 'Importing 『${name}』...';
	String get import_entries => 'Processing entries...';
	String import_found_entry({required Object count}) => 'Found ${count} entries...';
	String import_found_tag({required Object count}) => 'Found ${count} tags...';
	String import_found_frequency({required Object count}) => 'Found ${count} frequency entries...';
	String import_found_pitch({required Object count}) => 'Found ${count} pitch accent entries...';
	String import_write_entry({required Object count, required Object total}) => 'Writing entries:\n${count} / ${total}';
	String import_write_tag({required Object count, required Object total}) => 'Writing tags:\n${count} / ${total}';
	String import_write_frequency({required Object count, required Object total}) => 'Writing frequency entries:\n${count} / ${total}';
	String import_write_pitch({required Object count, required Object total}) => 'Writing pitch accent entries:\n${count} / ${total}';
	String get import_failed => 'Dictionary import failed.';
	String get import_complete => 'Dictionary import complete.';
	String import_duplicate({required Object name}) => 'A dictionary with the name『${name}』is already imported.';
	String get dialog_title_dictionary_clear => 'Clear all dictionaries?';
	String get dialog_content_dictionary_clear => 'Wiping the dictionary database will also clear all search results in history.';
	String dialog_title_dictionary_delete({required Object name}) => 'Delete 『${name}』?';
	String get dialog_content_dictionary_delete => 'Deleting a single dictionary may take longer than clearing the entire dictionary database. This will also clear all search results in history.';
	String get delete_dictionary_data => 'Clearing all dictionary data...';
	String dictionary_tag({required Object name}) => 'Imported from ${name}';
	String get legalese => 'A full-featured immersion language learning suite for mobile.\n\nOriginally built for the Japanese language learning community by Arianne Orpilla. Logo by suzy and Aaron Marbella.\n\njidoujisho is free and open source software. See the project repository for a comprehensive list of other licenses and attribution notices. Enjoying the application? Help out by providing feedback, making a donation, reporting issues or contributing improvements on GitHub.';
	String get same_name_dictionary_found => 'Dictionary with same name found.';
	String import_file_extension_invalid({required Object extensions}) => 'This format expects files with the following extensions: ${extensions}';
	String get field_label_empty => 'Empty';
	String get model_to_map => 'Card type to use for new profile';
	String get mapping_name => 'Profile name';
	String get mapping_name_hint => 'Name to assign to profile';
	String get error_profile_name => 'Invalid profile name';
	String get error_profile_name_content => 'A profile with this name already exists or is not valid and cannot be saved.';
	String get error_standard_profile_name => 'Invalid profile name';
	String get error_standard_profile_name_content => 'Cannot rename the standard profile.';
	String get error_ankidroid_api => 'AnkiDroid error';
	String get error_ankidroid_api_content => 'There was an issue communicating with AnkiDroid.\n\nEnsure that the AnkiDroid background service is active and all relevant app permissions are granted in order to continue.';
	String get info_standard_model => 'Standard card type added';
	String get info_standard_model_content => '『jidoujisho Kinomoto』 has been added to AnkiDroid as a new card type.\n\nSetups making use of a different card type or field order may be used by adding a new export profile.';
	String get error_model_missing => 'Missing card type';
	String get error_model_missing_content => 'The corresponding card type of the currently selected profile is missing.\n\nThe profile will be deleted, and the standard profile has now been selected in its place.';
	String get error_model_changed => 'Card type changed';
	String get error_model_changed_content => 'The number of fields of the card type corresponding to the selected profile has changed.\n\nThe fields of the currently selected profile have been reset and will require reconfiguration.';
	String get creator_exporting_as => 'Creating card with profile';
	String get creator_exporting_as_fields_editing => 'Editing fields for profile';
	String get creator_exporting_as_enhancements_editing => 'Editing enhancements for profile';
	String get creator_export_card => 'Create Card';
	String get info_enhancements => 'Enhancements enable the automation of field editing prior to card creation. Pick a slot on the right of a field to allow use of an enhancement. Up to five right slots may be utilised for each field. The enhancement in the left slot of a field will be automatically applied in instant card creation or upon launch of the Card Creator.';
	String get info_actions => 'Quick actions allow for instant card creation and other automations to be used on dictionary search results. Actions can be assigned via the slots below. Up to six slots may be utilised.';
	String get no_more_available_enhancements => 'No more available enhancements for this field';
	String get no_more_available_quick_actions => 'No more available quick actions';
	String get assign_auto_enhancement => 'Assign Auto Enhancement';
	String get assign_manual_enhancement => 'Assign Manual Enhancement';
	String get remove_enhancement => 'Remove Enhancement';
	String copy_of_mapping({required Object name}) => 'Copy of ${name}';
	String get enter_search_term => 'Enter a search term...';
	String searching_for({required Object searchTerm}) => 'Searching for 『${searchTerm}』...';
	String get no_search_results => 'No search results found.';
	String get edit_actions => 'Edit Dictionary Quick Actions';
	String get remove_action => 'Remove Action';
	String get assign_action => 'Assign Action';
	String dictionary_import_tag({required Object name}) => 'Imported from ${name}';
	String stash_added_single({required Object term}) => '『${term}』has been added to the Stash.';
	String get stash_added_multiple => 'Multiple items have been added to the Stash.';
	String stash_clear_single({required Object term}) => '『${term}』has been removed from the Stash.';
	String get stash_clear_title => 'Clear Stash';
	String get stash_clear_description => 'All contents will be cleared. Are you sure?';
	String get stash_placeholder => 'No items in the Stash';
	String get stash_nothing_to_pop => 'No items to be popped from the Stash.';
	String get no_sentences_found => 'No sentences found';
	String get failed_online_service => 'Failed to communicate with online service';
	String get search_label_before => 'Show all ';
	String get search_label_middle => 'out of ';
	String get search_label_after => 'search results found for';
	String get clear_dictionary_title => 'Clear Dictionary Result History';
	String get clear_dictionary_description => 'This will clear all dictionary results from history. Are you sure?';
	String get clear_search_title => 'Clear Search History';
	String get clear_search_description => 'This will clear all search terms for this history. Are you sure?';
	String get clear_creator_title => 'Clear Creator';
	String get clear_creator_description => 'This will clear all fields. Are you sure?';
	String get copied_to_clipboard => 'Copied to clipboard.';
	String get no_text => 'No text.';
	String get info_fields => 'Fields are pre-filled based on the term selected on instant export or prior to opening the Card Creator. In order to include a field for card export, it must be enabled below as well as mapped in the current selected export profile. Enabled fields may also be collapsed below in order to reduce clutter during editing. Use the Clear button on the top-right of the Card Creator in order to wipe these hidden fields quickly when manually editing a card.';
	String get edit_fields => 'Edit and Reorder Fields';
	String get remove_field => 'Remove Field';
	String get add_field => 'Assign Field';
	String get add_field_hint => 'Assign a field to this row';
	String get no_more_available_fields => 'No more available fields';
	String get hidden_fields => 'Additional fields';
	String field_fallback_used({required Object field, required Object secondField}) => 'The ${field} field used ${secondField} as its fallback search term.';
	String get no_text_to_search => 'No text to search.';
	String get image_search_label_before => 'Selecting image ';
	String get image_search_label_middle => 'out of ';
	String get image_search_label_after => 'found for';
	String get image_search_label_none_middle => 'no image ';
	String get image_search_label_none_before => 'Selecting ';
	String get preparing_instant_export => 'Preparing card for export...';
	String get processing_in_progress => 'Preparing images';
	String get searching_in_progress => 'Searching for ';
	String get audio_unavailable => 'No audio could be found.';
	String get no_audio_enhancements => 'No audio enhancements are assigned.';
	String card_exported({required Object deck}) => 'Card exported to 『${deck}』.';
	String get info_incognito_on => 'Incognito mode on. Dictionary, media and search history will not be tracked.';
	String get info_incognito_off => 'Incognito mode off. Dictionary, media and search history will be tracked.';
	String get exit_media_title => 'Exit Media';
	String get exit_media_description => 'This will return you to the main menu. Are you sure?';
	String get unimplemented_source => 'Unimplemented source';
	String get clear_browser_title => 'Clear Browser Data';
	String get clear_browser_description => 'This will clear all browsing data used in media sources that use web content. Are you sure?';
	String get ttu_no_books_added => 'No books added to ッツ Ebook Reader';
	String get local_media_directory_empty => 'Directory has no folders or video';
	String get pick_video_file => 'Pick Video File';
	String get navigate_up_one_directory_level => 'Navigate Up One Directory Level';
	String get play => 'Play';
	String get pause => 'Pause';
	String get record => 'Record';
	String get stop => 'Stop';
	String get replay => 'Replay';
	String get audio_subtitles => 'Audio/Subtitles';
	String get player_option_shadowing => 'Shadowing Mode';
	String get player_option_change_mode => 'Change Playback Mode';
	String get player_option_listening_comprehension => 'Listening Comprehension Mode';
	String get player_option_drag_to_select => 'Use Drag to Select Subtitle Selection';
	String get player_option_tap_to_select => 'Use Tap to Select Subtitle Selection';
	String get player_option_dictionary_menu => 'Select Active Dictionary Source';
	String get player_option_cast_video => 'Cast to Display Device';
	String get player_option_share_subtitle => 'Share Current Subtitle';
	String get player_option_export => 'Create Card from Context';
	String get player_option_audio => 'Audio';
	String get player_option_subtitle => 'Subtitle';
	String get player_option_subtitle_external => 'External';
	String get player_option_subtitle_none => 'None';
	String get player_option_select_subtitle => 'Select Subtitle Track';
	String get player_option_select_audio => 'Select Audio Track';
	String get player_option_text_filter => 'Use Regular Expression Filter';
	String get player_option_blur_preferences => 'Blur Widget Preferences';
	String get player_option_blur_use => 'Use Blur Widget';
	String get player_option_blur_radius => 'Blur radius';
	String get player_option_blur_options => 'Set Blur Widget Color and Bluriness';
	String get player_option_blur_reset => 'Reset Blur Widget Size and Position';
	String get player_align_subtitle_transcript => 'Align Subtitle with Transcript';
	String get player_option_subtitle_appearance => 'Subtitle Timing and Appearance';
	String get player_option_load_subtitles => 'Load External Subtitles';
	String get player_option_subtitle_delay => 'Subtitle delay';
	String get player_option_audio_allowance => 'Audio allowance';
	String get player_option_font_name => 'Subtitle font name';
	String get player_option_font_size => 'Subtitle font size';
	String get player_option_regex_filter => 'Regular expression filter';
	String get player_option_subtitle_background_opacity => 'Subtitle background opacity';
	String get player_option_subtitle_background_blur_radius => 'Subtitle background blur radius';
	String get player_option_outline_width => 'Subtitle outline width';
	String get player_option_subtitle_always_above_bottom_bar => 'Always show subtitle above bottom bar area';
	String get player_subtitles_transcript_empty => 'Transcript is empty.';
	String get player_prepare_export => 'Preparing card...';
	String get player_change_player_orientation => 'Change Player Orientation';
	String get no_current_media => 'Play or refresh media for lyrics';
	String get lyrics_permission_required => 'Required permission not granted';
	String get no_lyrics_found => 'No lyrics found';
	String get trending => 'Trending';
	String get caption_filter => 'Filter Closed Captions';
	String get captions_query => 'Querying for captions';
	String get captions_target => 'Target language';
	String get captions_app => 'App language';
	String get captions_other => 'Other language';
	String get captions_closed => 'Closed captioning';
	String get captions_auto => 'Automatic captioning';
	String get captions_unavailable => 'No captioning';
	String get captions_error => 'Error while querying captions';
	String get change_quality => 'Change Quality';
	String get closed_captions_query => 'Querying for captions';
	String get closed_captions_target => 'Target language captions';
	String get closed_captions_app => 'App language captions';
	String get closed_captions_other => 'Other language captions';
	String get closed_captions_unavailable => 'No captions';
	String get closed_captions_error => 'Error while querying captions';
	String get stream_url => 'Stream URL';
	String get default_option => 'Default';
	String get paste => 'Paste';
	String get select_all => 'Select all';
	String get lyrics_title => 'Title';
	String get lyrics_artist => 'Artist';
	String get set_media => 'Set Media';
	String get no_recordings_found => 'No recordings found';
	String get wrap_image_audio => 'Include image/audio HTML tags on export';
	String get server_address => 'Server Address';
	String get no_active_connection => 'No active connection';
	String get failed_server_connection => 'Failed to connect to server';
	String get no_text_received => 'No text received';
	String get text_segmentation => 'Text Segmentation';
	String get connect_disconnect => 'Connect/Disconnect';
	String get clear_text_title => 'Clear Text';
	String get clear_text_description => 'This will clear all received text. Are you sure?';
	String get close_connection_title => 'Close Connection';
	String get close_connection_description => 'This will end the WebSocket connection and clear all received text. Are you sure?';
	String get use_slow_import => 'Slow import (use if failing)';
	String get settings => 'Settings';
	String get manager => 'Manager';
	String get volume_button_page_turning => 'Volume button page turning';
	String get invert_volume_buttons => 'Invert volume buttons';
	String get volume_button_turning_speed => 'Continuous scrolling speed';
	String get extend_page_beyond_navbar => 'Extend page beyond navigation bar';
	String get tweaks => 'Tweaks';
	String get increase => 'Increase';
	String get decrease => 'Decrease';
	String get unit_milliseconds => 'ms';
	String get unit_pixels => 'px';
	String get dictionary_settings => 'Dictionary Settings';
	String get auto_search => 'Auto search';
	String get auto_search_debounce_delay => 'Auto search debounce delay';
	String get dictionary_font_size => 'Dictionary font size';
	String get close_on_export => 'Close on Export';
	String get close_on_export_on => 'The Card Creator will now automatically close upon card export.';
	String get close_on_export_off => 'The Card Creator will no longer close upon card export.';
	String get export_profile_empty => 'Your export profile has no set fields and requires configuration.';
	String get error_export_media_ankidroid => 'There was an error in exporting media to AnkiDroid.';
	String get error_add_note => 'There was an error in adding a note to AnkiDroid.';
	String get first_time_setup => 'First-Time Setup';
	String get first_time_setup_description => 'Welcome to jidoujisho! Set your target language and a default profile will be tailored for you. You can change this later at anytime.';
	String get maximum_entries => 'Maximum dictionary entry query limit';
	String get maximum_terms => 'Maximum dictionary headwords in result';
	String get use_br_tags => 'Use line break tag instead of newline on export';
	String get prepend_dictionary_names => 'Prepend dictionary name in meaning';
	String get highlight_on_tap => 'Highlight text on tap';
	String get no_audio_file => 'No audio file to save.';
	String get storage_permissions => 'Please grant the following permissions for exporting to AnkiDroid.';
	String get stream => 'Stream';
	String get network_subtitles_warning => 'Embedded subtitles are unsupported for network streams.';
	String get accessibility => 'Permission is required to capture text from accessibility events.';
	String get comments => 'Comments';
	String get replies => 'Replies';
	String get no_comments_queried => 'No comments queried';
	String get no_text_in_clipboard => 'No text to display';
	String file_downloaded({required Object name}) => 'File downloaded: ${name}';
	String get cfhange_sort_order => 'Change Sort Order';
	String get login => 'Login';
	String get send => 'Send';
	String get no_messages => 'Start a chat';
	String get enter_message => 'Enter message...';
	String get clear_message_title => 'Clear Messages';
	String get clear_message_description => 'This will clear all messages and start a new chat. Are you sure?';
	String get error_chatgpt_response => 'Request failed or rate-limited. Try again shortly or check your usage limits.';
	String get pick_file => 'Pick File';
	String get open_url => 'Open URL';
	String get catalogs => 'Catalogs';
	String get name => 'Name';
	String get url => 'URL';
	String get duplicate_catalog => 'A catalog with this URL already exists.';
	String get no_catalogs_listed => 'No catalogs listed';
	String get go_back => 'Go Back';
	String get invalid_mokuro_file => 'File is not a Mokuro generated HTML file.';
	String get create_catalog => 'Create Catalog';
	String get adapt_ttu_theme => 'Adapt dictionary popup to theme';
	String get sentence_picker => 'Sentence Picker';
	String field_locked({required Object field}) => '${field} locked and will not clear on export while Creator is active.';
	String field_unlocked({required Object field}) => '${field} unlocked and will clear on export.';
	String get field_lock => 'Lock Field';
	String get field_unlock => 'Unlock Field';
	String get use_dark_theme => 'Use dark theme';
	String get stretch_to_fill_screen => 'Stretch to Fill Screen';
	String get processing_embedded_subtitles => 'Embedded subtitles are processing. Try again later.';
	String get transcript_playback_mode => 'Transcript Playback Mode';
	String get toggle_transcript_background => 'Toggle Transcript Background';
	String get seek => 'Seek';
	String get saved_tags => 'Tags saved.';
	String structured_content_first({required Object i}) => '${i} definitions are unsupported and were omitted.';
	String get structured_content_second => 'Consider a non-structured content version of this dictionary.';
	String get missing_api_key => 'API key not provided';
	String get chatgpt_error => 'There was an error in getting a response from ChatGPT.';
	String get api_key => 'API Key';
	String subtitle_delay_set({required Object ms}) => 'Subtitle delay set to ${ms} ms.';
	String get cancel => 'Cancel';
	String get server_port_in_use => 'Local server port already in use';
	String get google_fonts => 'Google Fonts';
	String get video_show => 'Show video';
	String get video_hide => 'Hide video';
	String get subtitle_timing_show => 'Show subtitle timings';
	String get subtitle_timing_hide => 'Hide subtitle timings';
	String get find_next => 'Find Next';
	String get find_previous => 'Find Previous';
	String get shadowing_mode => 'Shadowing Mode';
	String get display_settings => 'Display Settings';
	String get cloze => 'Cloze';
	String get info_standard_update => 'New standard profile card type';
	String get info_standard_update_content => 'The standard profile now uses the『jidoujisho Kinomoto』 card type.\n\nYour legacy standard profile remains available for backwards compatibility.';
	late final _StringsRetryingInEn retrying_in = _StringsRetryingInEn._(_root);
	late final _StringsViewRepliesEn view_replies = _StringsViewRepliesEn._(_root);
	String get manage_duplicate_checks => 'Manage Duplicate Checks';
	String get playback_normal => 'Normal Playback Mode';
	String get playback_condensed => 'Condensed Playback Mode';
	String get playback_auto_pause => 'Subtitle Pause Playback Mode';
	String get player_hardware_acceleration => 'Hardware acceleration';
	String get player_use_opensles => 'OpenSL ES audio';
	String get go_forward => 'Go Forward';
	String get browse => 'Browse';
	String get bookmark => 'Bookmark';
	String get add_bookmark => 'Add Bookmark';
	String get add_to_reading_list => 'Add To Reading List';
	String get reading_list_empty => 'Reading list is empty';
	String get reading_list_add_toast => 'Added to reading list.';
	String get reading_list_remove_toast => 'Removed from the reading list.';
	String get ad_block_hosts => 'Ad-block hosts';
	String get error_parsing_hosts_file => 'Error parsing hosts file.';
	String get double_tap_seek_duration => 'Double tap seek duration';
	String get player_background_play => 'Background play';
	String get loaded_from_cache => 'Loaded from web archive cache.';
	String get player_show_subtitle_in_notification => 'Show subtitles in media notification';
	String get subtitles_processing => 'Subtitles are processing...';
	String get video_unavailable => 'Video Unavailable';
	String get video_unavailable_content => 'Cannot fetch streams. There may be restrictions in place that prevent watching this video.';
	String get video_file_error => 'Cannot Load File';
	String get video_file_error_content => 'Unable to load the video file. Please ensure this file exists and is located in a directory accessible by the application.';
	String get ttu_add => 'Add';
	String get ttu_add_book => 'Add a book';
	String get ttu_reader_settings => 'Reader settings';
	String get ttu_reader_source => 'Reader source';
	String get ttu_empty_title => 'Your library is empty';
	String get ttu_empty_body => 'Add an EPUB or HTMLZ file to start reading. Tap any word to look it up as you go.';
	String get ttu_restore_backup => 'Restore from a backup';
	String ttu_adding_book({required Object name}) => 'Adding ${name}';
	String ttu_adding_books({required Object n}) => 'Adding ${n} books';
	String get ttu_reading_file => 'ッツ is reading the file';
	String ttu_added_book({required Object name}) => 'Added ${name}';
	String ttu_added_books({required Object n}) => 'Added ${n} books';
	String ttu_import_failed({required Object reason}) => 'Couldn\'t add the book: ${reason}';
	String ttu_unsupported_file({required Object name}) => '${name} isn\'t an EPUB or HTMLZ file';
	String get ttu_shelf_error => 'Couldn\'t read the library.';
	String get ttu_try_again => 'Try again';
	String ttu_book_deleted({required Object name}) => 'Deleted ${name}';
	String get ttu_undo => 'Undo';
	String get ttu_read => 'Read';
	String get ttu_continue => 'Continue';
	String get ttu_memo => 'Memo';
	String get ttu_memos => 'Memos';
	String get ttu_new_memo => 'New memo';
	String get ttu_edit_memo => 'Edit memo';
	String get ttu_memo_placeholder => 'A word to look up, a question, why this line matters';
	String ttu_memo_saved({required Object position}) => 'Memo saved at ${position}';
	String get ttu_memo_deleted => 'Memo deleted';
	String get ttu_no_memos => 'No memos yet. Select text in the book and tap Memo to add one.';
	String get ttu_no_memos_short => 'No memos';
	String get ttu_memo_hint => 'Add more while reading: select text, then tap Memo.';
	String get ttu_continue_reading => 'Continue reading';
	String get ttu_back_to_where => 'Back to where you were';
	String get ttu_before_jump => 'before your last jump';
	String get ttu_sort_position => 'Position';
	String get ttu_sort_newest => 'Newest';
	String ttu_read_percent({required Object percent}) => '${percent} read';
	String get ttu_edit => 'Edit';
	String get ttu_delete => 'Delete';
	String get ttu_progress => 'Progress';
	String get ttu_read_label => 'Read';
	String ttu_of_total({required Object total}) => 'of ${total}';
	String get ttu_last_opened => 'Last opened';
	String get ttu_not_opened => 'Not yet';
	String ttu_added_when({required Object when}) => 'Added ${when}';
	String get ttu_language => 'Language';
	String get ttu_uses_dictionaries => 'Looks words up in this language';
	String get ttu_page => 'Page';
	String get ttu_page_note => 'ッツ applies these when a book opens';
	String ttu_books_in({required Object language}) => '${language} books';
	String get ttu_theme => 'Theme';
	String get ttu_text_size => 'Text size';
	String get ttu_direction => 'Direction';
	String get ttu_vertical => 'Vertical';
	String get ttu_horizontal => 'Horizontal';
	String get ttu_layout => 'Layout';
	String get ttu_pages => 'Pages';
	String get ttu_scroll => 'Scroll';
	String get ttu_furigana => 'Show furigana';
	String get ttu_furigana_desc => 'Readings above kanji, when the book has them';
	String get ttu_while_reading => 'While reading';
	String get ttu_auto_save => 'Save my place';
	String get ttu_auto_save_desc => 'Saves as you read and when you leave a book';
	String get ttu_highlight => 'Highlight the looked-up word';
	String get ttu_highlight_desc => 'Marks the word the dictionary looked up';
	String get ttu_volume => 'Volume keys turn pages';
	String get ttu_volume_desc => 'Each press turns one page';
	String get ttu_volume_swap => 'Swap volume keys';
	String get ttu_volume_swap_desc => 'If the keys go the wrong way';
	String get ttu_scroll_step => 'Scroll step';
	String get ttu_scroll_step_desc => 'How far each key press scrolls in Scroll layout';
	String get ttu_full_screen => 'Full screen';
	String get ttu_full_screen_desc => 'Draws under the status bar. Best on phones without a notch';
	String get ttu_match_popup => 'Popup matches the page';
	String get ttu_match_popup_desc => 'Uses the page theme for the popup';
	String get ttu_more => 'More';
	String get ttu_backup_sync => 'Backup and sync';
	String get ttu_backup_sync_desc => 'Google Drive, OneDrive or a folder. Opens ッツ';
	String get ttu_all_settings => 'All ッツ settings';
	String get ttu_all_settings_desc => 'Fonts, margins, page columns and more. Opens ッツ';
	String get ttu_opening => 'Opening';
	String get ttu_jumping_to => 'Jumping to';
	String get ttu_returning_to => 'Back to';
	String ttu_back_to({required Object position}) => 'Back to ${position}';
	String ttu_saved_place({required Object position}) => 'Saved your place at ${position}';
	String get ttu_just_now => 'Just now';
	String ttu_minutes_ago({required Object n}) => '${n} min ago';
	String get ttu_today => 'Today';
	String get ttu_yesterday => 'Yesterday';
	String ttu_days_ago({required Object n}) => '${n} days ago';
	String get ttu_week_ago => '1 week ago';
	String ttu_weeks_ago({required Object n}) => '${n} weeks ago';
	String get ttu_month_ago => '1 month ago';
	String ttu_months_ago({required Object n}) => '${n} months ago';
	String get my_words => 'My terms';
	String get my_words_add => 'Add to My terms';
	String get my_words_edit => 'Edit term';
	String get my_words_word => 'Term';
	String get my_words_reading => 'Reading';
	String get my_words_meaning => 'Meaning (optional)';
	String get my_words_meaning_hint => 'Retrieval-augmented generation';
	String get my_words_saved => 'Saved to My terms';
	String get my_words_deleted => 'Term removed';
	String get my_words_empty => 'No terms yet';
	String get my_words_info => 'Your own meanings. They show first whenever you look the term up, in any book. Select text like "software as a service (SaaS)" and tap Add term to save SaaS in one tap.';
	String get my_words_new => 'New term';
	String get add_word => 'Add term';
	String get ttu_page_info => 'Books in this language open with these settings.';
	String get ttu_font => 'Font';
	String get ttu_font_serif => 'Serif';
	String get ttu_font_sans => 'Sans';
	String get ttu_font_mincho => 'Mincho';
	String get ttu_font_klee => 'Klee';
	String get ttu_line_spacing => 'Line spacing';
	String get ttu_margins => 'Margins';
	String get ttu_columns => 'Columns';
	String get ttu_columns_auto => 'Auto';
	String get ttu_furigana_label => 'Furigana';
	String get ttu_furigana_show => 'Show';
	String get ttu_furigana_faded => 'Faded';
	String get ttu_furigana_hidden => 'Hide';
	String get ttu_furigana_tap => 'On tap';
	String get ttu_furigana_info => 'Faded shows readings in grey. On tap shows them when you tap a word.';
	String get ttu_avoid_break => 'Keep paragraphs whole';
	String get ttu_avoid_break_info => 'Moves a paragraph to the next page instead of splitting it.';
	String get ttu_blur_images => 'Blur images';
	String get ttu_blur_images_info => 'Hides pictures behind a spoiler cover until you tap them.';
	String get ttu_full_screen_info => 'Hides the status and navigation bars. A swipe from the edge then only shows them, so it takes two swipes to leave or open notifications.';
	String get ttu_camera_area => 'Use the camera area';
	String get ttu_camera_area_info => 'Lets the page run under the camera cutout.';
	String get ttu_keep_screen_on => 'Keep the screen on';
	String get ttu_auto_save_info => 'Saves as you read and when you leave a book.';
	String get ttu_match_popup_info => 'Uses the page theme for the dictionary popup.';
	String get ttu_scroll_step_info => 'How far each key press scrolls in Scroll layout.';
	String get file_access_title => 'Allow access to your files?';
	String get file_access_media => 'Photos, videos and audio';
	String get file_access_all => 'All files';
	String get file_access_allow => 'Allow';
	String get file_access_not_now => 'Not now';
	String get file_access_info => 'Needed to open videos and manga from folders on your phone. Photos, videos and audio is enough to play videos; All files also finds subtitle files next to them. Books and dictionaries never need this.';
	String get file_access_info_short => 'Needed to open videos and manga from folders on your phone. Books and dictionaries never need this.';
	String get file_access_denied => 'Files can\'t be opened without access. You can allow it in Android settings.';
	String ttu_language_changed({required Object language}) => 'Words in this book are now looked up in ${language}';
	String my_terms_from({required Object title}) => 'From ${title}';
	String my_terms_saved_term({required Object term}) => 'Saved ${term}';
	String get my_terms_edit => 'Edit';
	String get ttu_terms => 'Terms';
	String get ttu_no_terms => 'No terms saved from this book yet';
	String ttu_place_kept({required Object position}) => 'Your place stays at ${position}';
	String get ttu_read_on => 'Read';
	String get ttu_font_genei => 'Genei';
	String get ttu_chapters => 'Chapters';
	String get ttu_no_chapters => 'This book has no chapter list';
	String get ttu_applying => 'Applying settings';
	String get ttu_memos_on_page => 'Show memos on the page';
	String get ttu_memos_on_page_info => 'A short note above each memo\'s passage. Tap it to read the whole memo.';
	String get ttu_color_amber => 'Amber';
	String get ttu_color_rose => 'Pink';
	String get ttu_color_green => 'Green';
	String get ttu_color_sky => 'Blue';
	String get ttu_color_violet => 'Purple';
	String get catalog_title => 'Online dictionaries';
	String get catalog_open => 'Online';
	String get catalog_connect_title => 'Connect a dictionary server';
	String get catalog_connect_hint => 'Paste the server\'s address and a token. A read token can browse and download; an admin token can also upload and delete. Pasting a link with the token after # fills in both.';
	String get catalog_address => 'Server address';
	String get catalog_token => 'Token';
	String get catalog_connect => 'Connect';
	String get catalog_all => 'All';
	String get catalog_section_bilingual => 'Bilingual';
	String get catalog_section_monolingual => 'Monolingual';
	String get catalog_section_kanji => 'Kanji';
	String get catalog_section_frequency => 'Frequency';
	String get catalog_section_pronunciation => 'Pronunciation';
	String get catalog_section_other => 'Other';
	String catalog_entries({required Object n}) => '${n} entries';
	String get catalog_installed => 'Installed';
	String get catalog_preparing => 'Preparing';
	String get catalog_failed => 'Couldn\'t prepare';
	String get catalog_download => 'Download';
	String get catalog_search_hint => 'Search this dictionary';
	String catalog_nothing_found({required Object query}) => 'Nothing found for ${query}';
	String get catalog_upload => 'Upload';
	String catalog_uploading({required Object name}) => 'Uploading ${name}';
	String catalog_uploaded({required Object name}) => '${name} is on the server and being prepared';
	String get catalog_replace => 'Replace';
	String get catalog_delete => 'Delete from server';
	String get catalog_delete_confirm => 'Tap again to delete';
	String catalog_deleted({required Object name}) => '${name} deleted from the server';
	String get catalog_words => 'Words';
	String get catalog_definitions => 'Definitions';
	String get catalog_languages_hint => 'The language you look words up in, and the language of the definitions. Dictionaries without this in their index are labelled by the server from their text; correct it here if it guessed wrong.';
	String get catalog_save => 'Save';
	String get catalog_server => 'Server';
	String get catalog_disconnect => 'Disconnect';
	String get catalog_role_admin => 'Admin';
	String get catalog_role_read => 'Read only';
	String get catalog_empty => 'No dictionaries on the server yet';
	String catalog_imported({required Object name}) => '${name} imported';
	String get catalog_unknown_language => 'Unknown';
	String get backup_title => 'Backup and restore';
	String get backup_menu => 'Backup and restore';
	String get backup_step_settings => 'Settings';
	String get backup_step_memos => 'Memos and terms';
	String backup_step_books({required Object language}) => 'Books (${language})';
	String backup_step_dictionary({required Object name}) => 'Dictionary: ${name}';
	String get backup_step_packing => 'Packing';
	String backup_step_download({required Object name}) => 'Downloading ${name}';
	String backup_step_install({required Object name}) => 'Installing ${name}';
	String get backup_not_a_backup => 'This file isn\'t a jidoujisho backup.';
	String get backup_too_new => 'This backup was made by a newer version of the app. Update the app to restore it.';
	String get backup_make => 'Back up';
	String get backup_make_hint => 'One file with your books and reading positions, ッツ\'s settings and fonts, memos, My terms, history, Anki profiles, app settings with your dictionary server link, and your dictionaries. Dictionaries that are on your dictionary server are downloaded again on restore; the others travel in the file. The file includes your server token, so keep it private.';
	String get backup_restore => 'Restore';
	String get backup_restore_hint => 'Replaces this device\'s books, memos, terms and settings with the backup\'s. Dictionaries already on this device are kept; the backup\'s others are installed.';
	String get backup_choose => 'Choose a backup';
	String get backup_saved => 'Backup saved';
	String get backup_not_saved => 'The backup wasn\'t saved';
	String get backup_books => 'Books';
	String get backup_dictionaries => 'Dictionaries';
	String backup_dictionaries_split({required Object included, required Object online}) => '${included} in the file · ${online} from your server';
	String get backup_memos => 'Memos';
	String get backup_terms => 'My terms';
	String backup_made({required Object date, required Object version}) => 'Made ${date} with ${version}';
	String get backup_restore_confirm => 'Tap again to replace this device\'s data';
	String get backup_restored => 'Restored. Restart the app to finish.';
	String get backup_restart => 'Close the app';
	String backup_failed_dictionaries({required Object names}) => 'Couldn\'t install: ${names}';
	String get backup_working => 'Keep the app open until this finishes.';
	String get theme_menu => 'Theme';
	String get theme_mode => 'Mode';
	String get theme_mode_system => 'System';
	String get theme_mode_light => 'Light';
	String get theme_mode_dark => 'Dark';
	String get theme_mode_hint => 'System follows your phone and switches with it.';
	String get theme_accent => 'Accent';
	String get theme_accent_red => 'Red';
	String get theme_accent_rose => 'Pink';
	String get theme_accent_orange => 'Orange';
	String get theme_accent_green => 'Green';
	String get theme_accent_teal => 'Teal';
	String get theme_accent_blue => 'Blue';
	String get theme_accent_violet => 'Purple';
	String get theme_accent_slate => 'Slate';
	String get ttu_search => 'Search';
	String get ttu_search_hint => 'Search this book';
	String ttu_search_found({required Object count}) => '${count} found';
	String ttu_search_first({required Object shown}) => 'The first ${shown} are listed';
	String get ttu_search_none => 'Not in this book';
	String get ttu_search_reading => 'Reading the book…';
	String get ttu_search_stay => 'Stay here';
	String get ttu_search_list => 'All results';
	String get ttu_search_previous => 'Previous result';
	String get ttu_search_next => 'Next result';
	String get ttu_search_info => 'Matches ignore the difference between hiragana and katakana, full- and half-width letters, and upper and lower case. Furigana is not searched. Your saved place stays where it was until you choose Stay here.';
	String get ttu_favourite => 'Favourite';
	String get ttu_unfavourite => 'Remove from favourites';
	String get ttu_favourites => 'Favourites';
	String get ttu_shelf => 'Shelf';
	String get ttu_group_by => 'Group by';
	String get ttu_group_by_none => 'None';
	String get ttu_group_by_groups => 'My groups';
	String get ttu_group_by_language => 'Language';
	String get ttu_group_by_progress => 'Progress';
	String get ttu_group => 'Group';
	String get ttu_group_none => 'None';
	String get ttu_ungrouped => 'Not in a group';
	String get ttu_progress_reading => 'Reading';
	String get ttu_progress_unread => 'Not started';
	String get ttu_progress_finished => 'Finished';
	String get ttu_other_books => 'Books';
	String get ttu_new_group => 'New group';
	String get ttu_group_name => 'Group name';
	String get ttu_rename_group => 'Rename';
	String get ttu_delete_group => 'Delete group';
	String get ttu_group_info => 'Books show under their group when the shelf is grouped by My groups, in the shelf settings.';
	String get ttu_group_by_info => 'Favourites always come first. Tap a heading to fold it away.';
	String get ttu_this_book => 'This book';
	String get ttu_follow_links => 'Follow links';
	String get ttu_follow_links_info => 'On, tapping a link takes you where it points, with a way back. Off, links read as plain text and tapping one looks the word up.';
	String get ttu_book_fonts => 'Book\'s own fonts';
	String get ttu_book_fonts_info => 'Off, your font is used all through the book. Code keeps its fixed-width font.';
	String ttu_repaired_partly({required Object title}) => 'Parts of ${title} were missing from the file. The rest was added.';
	String get catalog_description => 'Description';
	String get catalog_description_hint => 'What it\'s good for, or who it\'s for';
	String catalog_description_shown_in({required Object language}) => 'Shows only when the app is in ${language}';
	String import_replacing({required Object name}) => 'Replacing the older ${name}…';
	String get catalog_update => 'Update to this revision';
	String get dictionary_about => 'About';
	String dictionary_by({required Object author}) => 'By ${author}';
	String get dictionary_delete_all => 'Delete all dictionaries';
	String get dictionary_import => 'Import';
	String get dictionary_collapsed => 'Starts collapsed';
	String get dictionary_show_in_results => 'Show in results';
	String get dictionary_start_collapsed => 'Start collapsed in results';
	String get dictionary_from_server => 'Downloaded';
	String get dictionary_from_file => 'Imported from a file';
	String get dictionary_delete => 'Delete dictionary';
	String get ttu_add_font => 'Add font';
	String get ttu_font_unsupported => 'Fonts can be .ttf, .otf, .woff or .woff2 files.';
	String get ttu_font_failed => 'The font could not be added.';
	String ttu_remove_font({required Object name}) => 'Remove ${name}';
	String get auto_backup_title => 'Keep a backup up to date';
	String get auto_backup_hint => 'One backup file, in a place you choose such as Google Drive, written over when it is due, so only the newest is kept. It updates while the app is open, a little after you open it.';
	String get auto_backup_choose => 'Choose where to keep it';
	String get auto_backup_file => 'Backup file';
	String get auto_backup_daily => 'Every day';
	String get auto_backup_weekly => 'Every week';
	String get auto_backup_own_dictionaries => 'Include dictionaries I added myself';
	String get auto_backup_own_dictionaries_info => 'They can make the file large. Dictionaries from your server are always listed and download again when restoring.';
	String get auto_backup_now => 'Update now';
	String get auto_backup_off => 'Turn off';
	String auto_backup_updated({required Object date}) => 'Updated ${date}';
	String get auto_backup_never => 'Not updated yet';
	String auto_backup_failed({required Object reason}) => 'Last update failed: ${reason}';
	String get auto_backup_lost => 'The backup file can no longer be reached. Choose where to keep it again.';
	String get auto_backup_writing => 'Writing the backup file';
	String get auto_backup_cannot_keep => 'That place can\'t be written to again later. Choose another, such as a folder or Google Drive.';
	String get auto_backup_running => 'Updating the backup file';
	String get ttu_tags => 'Tags';
	String get ttu_add_tag => 'Add a tag';
	String get ttu_tags_none => 'No tags yet';
	String get ttu_tags_used_before => 'Used before';
	String get ttu_tags_info => 'Tags show on the book\'s cover. Pick one you used before or type a new one.';
	late final _StringsTtuThemeNamesEn ttu_theme_names = _StringsTtuThemeNamesEn._(_root);
	late final _StringsLanguageNamesEn language_names = _StringsLanguageNamesEn._(_root);
	late final _StringsAddonsEn addons = _StringsAddonsEn._(_root);
}

// Path: retrying_in
class _StringsRetryingInEn {
	_StringsRetryingInEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String seconds({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Retrying in ${n} second...',
		other: 'Retrying in ${n} seconds...',
	);
}

// Path: view_replies
class _StringsViewRepliesEn {
	_StringsViewRepliesEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String reply({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'SHOW ${n} REPLY',
		other: 'SHOW ${n} REPLIES',
	);
}

// Path: ttu_theme_names
class _StringsTtuThemeNamesEn {
	_StringsTtuThemeNamesEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get light => 'Light';
	String get ecru => 'Ecru';
	String get water => 'Water';
	String get gray => 'Gray';
	String get dark => 'Dark';
	String get black => 'Black';
}

// Path: language_names
class _StringsLanguageNamesEn {
	_StringsLanguageNamesEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get ja => 'Japanese';
	String get en => 'English';
	String get vi => 'Vietnamese';
	String get zh => 'Chinese';
	String get ko => 'Korean';
	String get fr => 'French';
	String get de => 'German';
	String get es => 'Spanish';
	String get ru => 'Russian';
	String get th => 'Thai';
	String get ar => 'Arabic';
}

// Path: addons
class _StringsAddonsEn {
	_StringsAddonsEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	late final _StringsAddonsFieldEn field = _StringsAddonsFieldEn._(_root);
	late final _StringsAddonsEnhancementEn enhancement = _StringsAddonsEnhancementEn._(_root);
	late final _StringsAddonsActionEn action = _StringsAddonsActionEn._(_root);
	late final _StringsAddonsSourceEn source = _StringsAddonsSourceEn._(_root);
}

// Path: addons.field
class _StringsAddonsFieldEn {
	_StringsAddonsFieldEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	late final _StringsAddonsFieldSentenceEn sentence = _StringsAddonsFieldSentenceEn._(_root);
	late final _StringsAddonsFieldTermEn term = _StringsAddonsFieldTermEn._(_root);
	late final _StringsAddonsFieldReadingEn reading = _StringsAddonsFieldReadingEn._(_root);
	late final _StringsAddonsFieldMeaningEn meaning = _StringsAddonsFieldMeaningEn._(_root);
	late final _StringsAddonsFieldNotesEn notes = _StringsAddonsFieldNotesEn._(_root);
	late final _StringsAddonsFieldImageEn image = _StringsAddonsFieldImageEn._(_root);
	late final _StringsAddonsFieldAudioEn audio = _StringsAddonsFieldAudioEn._(_root);
	late final _StringsAddonsFieldAudioSentenceEn audio_sentence = _StringsAddonsFieldAudioSentenceEn._(_root);
	late final _StringsAddonsFieldPitchAccentEn pitch_accent = _StringsAddonsFieldPitchAccentEn._(_root);
	late final _StringsAddonsFieldFuriganaEn furigana = _StringsAddonsFieldFuriganaEn._(_root);
	late final _StringsAddonsFieldFrequencyEn frequency = _StringsAddonsFieldFrequencyEn._(_root);
	late final _StringsAddonsFieldContextEn context = _StringsAddonsFieldContextEn._(_root);
	late final _StringsAddonsFieldClozeBeforeEn cloze_before = _StringsAddonsFieldClozeBeforeEn._(_root);
	late final _StringsAddonsFieldClozeInsideEn cloze_inside = _StringsAddonsFieldClozeInsideEn._(_root);
	late final _StringsAddonsFieldClozeAfterEn cloze_after = _StringsAddonsFieldClozeAfterEn._(_root);
	late final _StringsAddonsFieldExpandedMeaningEn expanded_meaning = _StringsAddonsFieldExpandedMeaningEn._(_root);
	late final _StringsAddonsFieldCollapsedMeaningEn collapsed_meaning = _StringsAddonsFieldCollapsedMeaningEn._(_root);
	late final _StringsAddonsFieldHiddenMeaningEn hidden_meaning = _StringsAddonsFieldHiddenMeaningEn._(_root);
	late final _StringsAddonsFieldTagsEn tags = _StringsAddonsFieldTagsEn._(_root);
}

// Path: addons.enhancement
class _StringsAddonsEnhancementEn {
	_StringsAddonsEnhancementEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	late final _StringsAddonsEnhancementClearFieldEn clear_field = _StringsAddonsEnhancementClearFieldEn._(_root);
	late final _StringsAddonsEnhancementJpd101AudioEn jpd101_audio = _StringsAddonsEnhancementJpd101AudioEn._(_root);
	late final _StringsAddonsEnhancementForvoAudioEn forvo_audio = _StringsAddonsEnhancementForvoAudioEn._(_root);
	late final _StringsAddonsEnhancementPickAudioEn pick_audio = _StringsAddonsEnhancementPickAudioEn._(_root);
	late final _StringsAddonsEnhancementAudioRecorderEn audio_recorder = _StringsAddonsEnhancementAudioRecorderEn._(_root);
	late final _StringsAddonsEnhancementOpenStashEn open_stash = _StringsAddonsEnhancementOpenStashEn._(_root);
	late final _StringsAddonsEnhancementPopFromStashEn pop_from_stash = _StringsAddonsEnhancementPopFromStashEn._(_root);
	late final _StringsAddonsEnhancementTextSegmentationEn text_segmentation = _StringsAddonsEnhancementTextSegmentationEn._(_root);
	late final _StringsAddonsEnhancementBingImagesSearchEn bing_images_search = _StringsAddonsEnhancementBingImagesSearchEn._(_root);
	late final _StringsAddonsEnhancementCropImageEn crop_image = _StringsAddonsEnhancementCropImageEn._(_root);
	late final _StringsAddonsEnhancementPickImageEn pick_image = _StringsAddonsEnhancementPickImageEn._(_root);
	late final _StringsAddonsEnhancementCameraEn camera = _StringsAddonsEnhancementCameraEn._(_root);
	late final _StringsAddonsEnhancementSentencePickerEn sentence_picker = _StringsAddonsEnhancementSentencePickerEn._(_root);
	late final _StringsAddonsEnhancementSearchDictionaryEn search_dictionary = _StringsAddonsEnhancementSearchDictionaryEn._(_root);
	late final _StringsAddonsEnhancementMassifExampleSentencesEn massif_example_sentences = _StringsAddonsEnhancementMassifExampleSentencesEn._(_root);
	late final _StringsAddonsEnhancementTatoebaExampleSentencesEn tatoeba_example_sentences = _StringsAddonsEnhancementTatoebaExampleSentencesEn._(_root);
	late final _StringsAddonsEnhancementImmersionKitEn immersion_kit = _StringsAddonsEnhancementImmersionKitEn._(_root);
	late final _StringsAddonsEnhancementSaveTagsEn save_tags = _StringsAddonsEnhancementSaveTagsEn._(_root);
}

// Path: addons.action
class _StringsAddonsActionEn {
	_StringsAddonsActionEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	late final _StringsAddonsActionCardCreatorEn card_creator = _StringsAddonsActionCardCreatorEn._(_root);
	late final _StringsAddonsActionInstantExportEn instant_export = _StringsAddonsActionInstantExportEn._(_root);
	late final _StringsAddonsActionAddToStashEn add_to_stash = _StringsAddonsActionAddToStashEn._(_root);
	late final _StringsAddonsActionMyWordsEn my_words = _StringsAddonsActionMyWordsEn._(_root);
	late final _StringsAddonsActionCopyToClipboardEn copy_to_clipboard = _StringsAddonsActionCopyToClipboardEn._(_root);
	late final _StringsAddonsActionShareEn share = _StringsAddonsActionShareEn._(_root);
	late final _StringsAddonsActionPlayAudioEn play_audio = _StringsAddonsActionPlayAudioEn._(_root);
}

// Path: addons.source
class _StringsAddonsSourceEn {
	_StringsAddonsSourceEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	late final _StringsAddonsSourcePlayerLocalMediaEn player_local_media = _StringsAddonsSourcePlayerLocalMediaEn._(_root);
	late final _StringsAddonsSourcePlayerYoutubeEn player_youtube = _StringsAddonsSourcePlayerYoutubeEn._(_root);
	late final _StringsAddonsSourcePlayerNetworkStreamEn player_network_stream = _StringsAddonsSourcePlayerNetworkStreamEn._(_root);
	late final _StringsAddonsSourceReaderTtuEn reader_ttu = _StringsAddonsSourceReaderTtuEn._(_root);
	late final _StringsAddonsSourceReaderMokuroEn reader_mokuro = _StringsAddonsSourceReaderMokuroEn._(_root);
	late final _StringsAddonsSourceReaderBrowserEn reader_browser = _StringsAddonsSourceReaderBrowserEn._(_root);
	late final _StringsAddonsSourceReaderLyricsEn reader_lyrics = _StringsAddonsSourceReaderLyricsEn._(_root);
	late final _StringsAddonsSourceReaderChatgptEn reader_chatgpt = _StringsAddonsSourceReaderChatgptEn._(_root);
	late final _StringsAddonsSourceReaderClipboardEn reader_clipboard = _StringsAddonsSourceReaderClipboardEn._(_root);
	late final _StringsAddonsSourceReaderWebsocketEn reader_websocket = _StringsAddonsSourceReaderWebsocketEn._(_root);
	late final _StringsAddonsSourceViewerCameraEn viewer_camera = _StringsAddonsSourceViewerCameraEn._(_root);
}

// Path: addons.field.sentence
class _StringsAddonsFieldSentenceEn {
	_StringsAddonsFieldSentenceEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Sentence';
	String get description => 'Subtitles, book excerpts and other contextual information.';
}

// Path: addons.field.term
class _StringsAddonsFieldTermEn {
	_StringsAddonsFieldTermEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Term';
	String get description => 'Dictionary headword or phrase.';
}

// Path: addons.field.reading
class _StringsAddonsFieldReadingEn {
	_StringsAddonsFieldReadingEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Reading';
	String get description => 'Pronunciation or speech pattern.';
}

// Path: addons.field.meaning
class _StringsAddonsFieldMeaningEn {
	_StringsAddonsFieldMeaningEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Meaning';
	String get description => 'All dictionary definitions of a term.';
}

// Path: addons.field.notes
class _StringsAddonsFieldNotesEn {
	_StringsAddonsFieldNotesEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Notes';
	String get description => 'Supplementary information or personal observations.';
}

// Path: addons.field.image
class _StringsAddonsFieldImageEn {
	_StringsAddonsFieldImageEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Image';
	String get description => 'Visual supplement. Text field can be used to enter search terms for image sources.';
}

// Path: addons.field.audio
class _StringsAddonsFieldAudioEn {
	_StringsAddonsFieldAudioEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Term Audio';
	String get description => 'Audio pertaining to the term. Text field can be used to enter search terms for audio sources.';
}

// Path: addons.field.audio_sentence
class _StringsAddonsFieldAudioSentenceEn {
	_StringsAddonsFieldAudioSentenceEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Sentence Audio';
	String get description => 'Audio pertaining to the sentence. Text field can be used to enter search terms for audio sources.';
}

// Path: addons.field.pitch_accent
class _StringsAddonsFieldPitchAccentEn {
	_StringsAddonsFieldPitchAccentEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Pitch Accent';
	String get description => 'Pre-fills text to export for pitch accent diagrams.';
}

// Path: addons.field.furigana
class _StringsAddonsFieldFuriganaEn {
	_StringsAddonsFieldFuriganaEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Furigana';
	String get description => 'Pre-fills text to export for Furigana.';
}

// Path: addons.field.frequency
class _StringsAddonsFieldFrequencyEn {
	_StringsAddonsFieldFrequencyEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Frequency';
	String get description => 'Adds frequency of headword for sorting purposes, calculated using the harmonic mean.';
}

// Path: addons.field.context
class _StringsAddonsFieldContextEn {
	_StringsAddonsFieldContextEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Context';
	String get description => 'Name of current source media.';
}

// Path: addons.field.cloze_before
class _StringsAddonsFieldClozeBeforeEn {
	_StringsAddonsFieldClozeBeforeEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Cloze Before';
	String get description => 'Text before highlighted text in a sentence. Empty if nothing is highlighted.';
}

// Path: addons.field.cloze_inside
class _StringsAddonsFieldClozeInsideEn {
	_StringsAddonsFieldClozeInsideEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Cloze Inside';
	String get description => 'Highlighted text in a sentence.';
}

// Path: addons.field.cloze_after
class _StringsAddonsFieldClozeAfterEn {
	_StringsAddonsFieldClozeAfterEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Cloze After';
	String get description => 'Text after highlighted text in a sentence. Empty if nothing is highlighted.';
}

// Path: addons.field.expanded_meaning
class _StringsAddonsFieldExpandedMeaningEn {
	_StringsAddonsFieldExpandedMeaningEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Expanded Meaning';
	String get description => 'Dictionary definitions only from expanded dictionaries.';
}

// Path: addons.field.collapsed_meaning
class _StringsAddonsFieldCollapsedMeaningEn {
	_StringsAddonsFieldCollapsedMeaningEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Collapsed Meaning';
	String get description => 'Dictionary definitions only from collapsed dictionaries.';
}

// Path: addons.field.hidden_meaning
class _StringsAddonsFieldHiddenMeaningEn {
	_StringsAddonsFieldHiddenMeaningEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Hidden Meaning';
	String get description => 'Dictionary definitions only from hidden dictionaries.';
}

// Path: addons.field.tags
class _StringsAddonsFieldTagsEn {
	_StringsAddonsFieldTagsEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Tags';
	String get description => 'Organise notes in a deck with space-delimited labels.';
}

// Path: addons.enhancement.clear_field
class _StringsAddonsEnhancementClearFieldEn {
	_StringsAddonsEnhancementClearFieldEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Clear Field';
	String get description => 'Quickly empty the content of a field.';
}

// Path: addons.enhancement.jpd101_audio
class _StringsAddonsEnhancementJpd101AudioEn {
	_StringsAddonsEnhancementJpd101AudioEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'JapanesePod101 Audio';
	String get description => 'Search for matching word pronunciations from JapanesePod101.';
}

// Path: addons.enhancement.forvo_audio
class _StringsAddonsEnhancementForvoAudioEn {
	_StringsAddonsEnhancementForvoAudioEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Forvo Audio';
	String get description => 'Get word audio from Forvo.';
}

// Path: addons.enhancement.pick_audio
class _StringsAddonsEnhancementPickAudioEn {
	_StringsAddonsEnhancementPickAudioEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Pick Audio';
	String get description => 'Pick an audio file to use with an external picker.';
}

// Path: addons.enhancement.audio_recorder
class _StringsAddonsEnhancementAudioRecorderEn {
	_StringsAddonsEnhancementAudioRecorderEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Audio Recorder';
	String get description => 'Record and use audio captured from the device microphone.';
}

// Path: addons.enhancement.open_stash
class _StringsAddonsEnhancementOpenStashEn {
	_StringsAddonsEnhancementOpenStashEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Open Stash';
	String get description => 'View and manage previously stashed text.';
}

// Path: addons.enhancement.pop_from_stash
class _StringsAddonsEnhancementPopFromStashEn {
	_StringsAddonsEnhancementPopFromStashEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Pop From Stash';
	String get description => 'Quickly pop the latest item in the Stash.';
}

// Path: addons.enhancement.text_segmentation
class _StringsAddonsEnhancementTextSegmentationEn {
	_StringsAddonsEnhancementTextSegmentationEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Text Segmentation';
	String get description => 'Search or select a new term from segmented text.';
}

// Path: addons.enhancement.bing_images_search
class _StringsAddonsEnhancementBingImagesSearchEn {
	_StringsAddonsEnhancementBingImagesSearchEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Bing Images Search';
	String get description => 'Search Bing for images with the current image query or the word.';
}

// Path: addons.enhancement.crop_image
class _StringsAddonsEnhancementCropImageEn {
	_StringsAddonsEnhancementCropImageEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Crop Image';
	String get description => 'Crop the current selected image.';
}

// Path: addons.enhancement.pick_image
class _StringsAddonsEnhancementPickImageEn {
	_StringsAddonsEnhancementPickImageEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Pick Image';
	String get description => 'Pick a new image to use with an external picker.';
}

// Path: addons.enhancement.camera
class _StringsAddonsEnhancementCameraEn {
	_StringsAddonsEnhancementCameraEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Camera';
	String get description => 'Take a new photo to use as the new image.';
}

// Path: addons.enhancement.sentence_picker
class _StringsAddonsEnhancementSentencePickerEn {
	_StringsAddonsEnhancementSentencePickerEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Sentence Picker';
	String get description => 'Pick sentences delimited by punctuation and spacing.';
}

// Path: addons.enhancement.search_dictionary
class _StringsAddonsEnhancementSearchDictionaryEn {
	_StringsAddonsEnhancementSearchDictionaryEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Search Dictionary';
	String get description => 'Search the dictionary with the content of a field.';
}

// Path: addons.enhancement.massif_example_sentences
class _StringsAddonsEnhancementMassifExampleSentencesEn {
	_StringsAddonsEnhancementMassifExampleSentencesEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Massif Example Sentences';
	String get description => 'Get curated example sentences via Massif.';
}

// Path: addons.enhancement.tatoeba_example_sentences
class _StringsAddonsEnhancementTatoebaExampleSentencesEn {
	_StringsAddonsEnhancementTatoebaExampleSentencesEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Tatoeba Example Sentences';
	String get description => 'Pick example phrases and sentences from Tatoeba.';
}

// Path: addons.enhancement.immersion_kit
class _StringsAddonsEnhancementImmersionKitEn {
	_StringsAddonsEnhancementImmersionKitEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'ImmersionKit';
	String get description => 'Get example sentences complete with an image and audio.';
}

// Path: addons.enhancement.save_tags
class _StringsAddonsEnhancementSaveTagsEn {
	_StringsAddonsEnhancementSaveTagsEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Save Tags';
	String get description => 'Persist the current text in the Tags field.';
}

// Path: addons.action.card_creator
class _StringsAddonsActionCardCreatorEn {
	_StringsAddonsActionCardCreatorEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Card Creator';
	String get description => 'Create a card with the selected dictionary entry parameters and edit before export.';
}

// Path: addons.action.instant_export
class _StringsAddonsActionInstantExportEn {
	_StringsAddonsActionInstantExportEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Instant Export';
	String get description => 'Export a card with the selected dictionary entry parameters.';
}

// Path: addons.action.add_to_stash
class _StringsAddonsActionAddToStashEn {
	_StringsAddonsActionAddToStashEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Add To Stash';
	String get description => 'Quickly save the headword of a dictionary entry to the Stash.';
}

// Path: addons.action.my_words
class _StringsAddonsActionMyWordsEn {
	_StringsAddonsActionMyWordsEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'My Terms';
	String get description => 'Write your own meaning for a term. It shows first whenever you look the term up.';
}

// Path: addons.action.copy_to_clipboard
class _StringsAddonsActionCopyToClipboardEn {
	_StringsAddonsActionCopyToClipboardEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Copy To Clipboard';
	String get description => 'Copy the headword of a dictionary entry to the clipboard.';
}

// Path: addons.action.share
class _StringsAddonsActionShareEn {
	_StringsAddonsActionShareEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Share';
	String get description => 'Share the details of a dictionary term.';
}

// Path: addons.action.play_audio
class _StringsAddonsActionPlayAudioEn {
	_StringsAddonsActionPlayAudioEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Play Audio';
	String get description => 'Attempts to play audio based on the Audio enhancements. The auto is the top priority.';
}

// Path: addons.source.player_local_media
class _StringsAddonsSourcePlayerLocalMediaEn {
	_StringsAddonsSourcePlayerLocalMediaEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Local Media';
	String get description => 'Play videos sourced from local device storage.';
}

// Path: addons.source.player_youtube
class _StringsAddonsSourcePlayerYoutubeEn {
	_StringsAddonsSourcePlayerYoutubeEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'YouTube';
	String get description => 'Search and watch videos from YouTube.';
}

// Path: addons.source.player_network_stream
class _StringsAddonsSourcePlayerNetworkStreamEn {
	_StringsAddonsSourcePlayerNetworkStreamEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Network Stream';
	String get description => 'Stream videos from a direct URL.';
}

// Path: addons.source.reader_ttu
class _StringsAddonsSourceReaderTtuEn {
	_StringsAddonsSourceReaderTtuEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'ッツ Ebook Reader';
	String get description => 'Read EPUBs and mine sentences via an embedded web reader.';
}

// Path: addons.source.reader_mokuro
class _StringsAddonsSourceReaderMokuroEn {
	_StringsAddonsSourceReaderMokuroEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Mokuro';
	String get description => 'Read manga volumes pre-processed as a single HTML file via Mokuro.';
}

// Path: addons.source.reader_browser
class _StringsAddonsSourceReaderBrowserEn {
	_StringsAddonsSourceReaderBrowserEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Browser';
	String get description => 'Navigate websites with a browser which allows searching and mining selected text.';
}

// Path: addons.source.reader_lyrics
class _StringsAddonsSourceReaderLyricsEn {
	_StringsAddonsSourceReaderLyricsEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Lyrics';
	String get description => 'Allows fetching and highlighting lyrics of current played media fetched from Google and Uta-Net.';
}

// Path: addons.source.reader_chatgpt
class _StringsAddonsSourceReaderChatgptEn {
	_StringsAddonsSourceReaderChatgptEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'ChatGPT';
	String get description => 'Allows the user to interact with an AI language model with an official API key from OpenAI.';
}

// Path: addons.source.reader_clipboard
class _StringsAddonsSourceReaderClipboardEn {
	_StringsAddonsSourceReaderClipboardEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Clipboard';
	String get description => 'Allows text pasted from the clipboard to be displayed as selectable text.';
}

// Path: addons.source.reader_websocket
class _StringsAddonsSourceReaderWebsocketEn {
	_StringsAddonsSourceReaderWebsocketEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'WebSocket';
	String get description => 'Select and mine text received from a WebSocket server.';
}

// Path: addons.source.viewer_camera
class _StringsAddonsSourceViewerCameraEn {
	_StringsAddonsSourceViewerCameraEn._(this._root);

	final _StringsEn _root; // ignore: unused_field

	// Translations
	String get label => 'Camera';
	String get description => 'View images taken with the camera or picked from media.';
}

// Path: <root>
class _StringsVi extends _StringsEn {

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_StringsVi.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.vi,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super.build(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <vi>.
	@override final TranslationMetadata<AppLocale, _StringsEn> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	@override late final _StringsVi _root = this; // ignore: unused_field

	// Translations
	@override String get dictionary_media_type => 'Từ điển';
	@override String get player_media_type => 'Trình phát';
	@override String get reader_media_type => 'Trình đọc';
	@override String get viewer_media_type => 'Trình xem';
	@override String get back => 'Quay lại';
	@override String get search => 'Tìm kiếm';
	@override String get search_ellipsis => 'Tìm kiếm...';
	@override String get show_more => 'Xem thêm';
	@override String get show_menu => 'Hiện menu';
	@override String get stash => 'Kho tạm';
	@override String get pick_image => 'Chọn ảnh';
	@override String get undo => 'Hoàn tác';
	@override String get copy => 'Sao chép';
	@override String get clear => 'Xóa';
	@override String get creator => 'Trình tạo';
	@override String get share => 'Chia sẻ';
	@override String get resume_last_media => 'Tiếp tục nội dung gần nhất';
	@override String get change_source => 'Đổi nguồn';
	@override String get launch_source => 'Mở nguồn';
	@override String get card_creator => 'Trình tạo thẻ';
	@override String get target_language => 'Ngôn ngữ đích';
	@override String get show_options => 'Hiện tùy chọn';
	@override String get switch_profiles => 'Đổi hồ sơ';
	@override String get dictionaries => 'Từ điển';
	@override String get enhancements => 'Tiện ích bổ trợ';
	@override String get app_locale => 'Ngôn ngữ ứng dụng';
	@override String get app_locale_warning => 'Các tiện ích cộng đồng và tiện ích bổ trợ được nhà phát triển tương ứng quản lý, nên có thể hiển thị bằng ngôn ngữ gốc.';
	@override String get dialog_play => 'PHÁT';
	@override String get dialog_read => 'ĐỌC';
	@override String get dialog_view => 'XEM';
	@override String get dialog_edit => 'SỬA';
	@override String get dialog_export => 'XUẤT';
	@override String get dialog_import => 'NHẬP';
	@override String get dialog_close => 'ĐÓNG';
	@override String get dialog_clear => 'XÓA';
	@override String get dialog_create => 'TẠO';
	@override String get dialog_delete => 'XÓA';
	@override String get dialog_cancel => 'HỦY';
	@override String get dialog_select => 'CHỌN';
	@override String get dialog_stash => 'KHO TẠM';
	@override String get dialog_search => 'TÌM KIẾM';
	@override String get dialog_exit => 'THOÁT';
	@override String get dialog_share => 'CHIA SẺ';
	@override String get dialog_pop => 'LẤY RA';
	@override String get dialog_save => 'LƯU';
	@override String get dialog_set => 'ĐẶT';
	@override String get dialog_browse => 'DUYỆT';
	@override String get dialog_channel => 'KÊNH';
	@override String get dialog_directory => 'THƯ MỤC';
	@override String get dialog_crop => 'CẮT';
	@override String get dialog_connect => 'KẾT NỐI';
	@override String get dialog_append => 'THÊM';
	@override String get dialog_record => 'GHI';
	@override String get dialog_manage => 'QUẢN LÝ';
	@override String get dialog_stop => 'DỪNG';
	@override String get dialog_done => 'XONG';
	@override String get reset => 'Đặt lại';
	@override String get dialog_launch_ankidroid => 'MỞ ANKIDROID';
	@override String get media_item_delete_confirmation => 'Mục này sẽ bị xóa khỏi lịch sử. Bạn có chắc muốn tiếp tục không?';
	@override String get dictionaries_delete_confirmation => 'Xóa một từ điển cũng sẽ xóa tất cả kết quả từ điển khỏi lịch sử. Bạn có chắc muốn tiếp tục không?';
	@override String get mappings_delete_confirmation => 'Hồ sơ này sẽ bị xóa. Bạn có chắc muốn tiếp tục không?';
	@override String get catalog_delete_confirmation => 'Danh mục này sẽ bị xóa. Bạn có chắc muốn tiếp tục không?';
	@override String get dictionaries_deleting_data => 'Đang xóa dữ liệu từ điển...';
	@override String get dictionaries_menu_empty => 'Nhập từ điển để sử dụng';
	@override String get options_theme_light => 'Dùng giao diện sáng';
	@override String get options_theme_dark => 'Dùng giao diện tối';
	@override String get options_incognito_on => 'Bật chế độ ẩn danh';
	@override String get options_incognito_off => 'Tắt chế độ ẩn danh';
	@override String get options_dictionaries => 'Quản lý từ điển';
	@override String get options_profiles => 'Hồ sơ xuất thẻ';
	@override String get options_enhancements => 'Tiện ích bổ trợ của người dùng';
	@override String get options_language => 'Cài đặt ngôn ngữ';
	@override String get options_github => 'Xem kho lưu trữ trên GitHub';
	@override String get options_attribution => 'Giấy phép và ghi công';
	@override String get options_copy => 'Sao chép';
	@override String get options_collapse => 'Thu gọn';
	@override String get options_expand => 'Mở rộng';
	@override String get options_delete => 'Xóa';
	@override String get options_show => 'Hiện';
	@override String get options_hide => 'Ẩn';
	@override String get options_edit => 'Sửa';
	@override String get info_empty_home_tab => 'Lịch sử trống';
	@override String get delete_in_progress => 'Đang xóa';
	@override String get import_format => 'Định dạng nhập';
	@override String get import_in_progress => 'Đang nhập';
	@override String get import_start => 'Đang chuẩn bị nhập...';
	@override String get import_clean => 'Đang dọn dẹp không gian làm việc...';
	@override String import_extract_count({required Object n}) => 'Đã giải nén ${n} tệp...';
	@override String get import_extract => 'Đang giải nén tệp...';
	@override String import_name({required Object name}) => 'Đang nhập 『${name}』...';
	@override String get import_entries => 'Đang xử lý các mục...';
	@override String import_found_entry({required Object count}) => 'Đã tìm thấy ${count} mục...';
	@override String import_found_tag({required Object count}) => 'Đã tìm thấy ${count} nhãn...';
	@override String import_found_frequency({required Object count}) => 'Đã tìm thấy ${count} mục tần suất...';
	@override String import_found_pitch({required Object count}) => 'Đã tìm thấy ${count} mục trọng âm...';
	@override String import_write_entry({required Object count, required Object total}) => 'Đang ghi các mục:\n${count} / ${total}';
	@override String import_write_tag({required Object count, required Object total}) => 'Đang ghi các nhãn:\n${count} / ${total}';
	@override String import_write_frequency({required Object count, required Object total}) => 'Đang ghi các mục tần suất:\n${count} / ${total}';
	@override String import_write_pitch({required Object count, required Object total}) => 'Đang ghi các mục trọng âm:\n${count} / ${total}';
	@override String get import_failed => 'Nhập từ điển không thành công.';
	@override String get import_complete => 'Đã nhập từ điển.';
	@override String import_duplicate({required Object name}) => 'Từ điển có tên 『${name}』 đã được nhập.';
	@override String get dialog_title_dictionary_clear => 'Xóa tất cả từ điển?';
	@override String get dialog_content_dictionary_clear => 'Xóa cơ sở dữ liệu từ điển cũng sẽ xóa tất cả kết quả tìm kiếm trong lịch sử.';
	@override String dialog_title_dictionary_delete({required Object name}) => 'Xóa 『${name}』?';
	@override String get dialog_content_dictionary_delete => 'Xóa một từ điển riêng lẻ có thể mất nhiều thời gian hơn xóa toàn bộ cơ sở dữ liệu từ điển. Thao tác này cũng sẽ xóa tất cả kết quả tìm kiếm trong lịch sử.';
	@override String get delete_dictionary_data => 'Đang xóa tất cả dữ liệu từ điển...';
	@override String dictionary_tag({required Object name}) => 'Được nhập từ ${name}';
	@override String get legalese => 'Bộ công cụ học ngôn ngữ qua đắm chìm (immersion), đầy đủ tính năng, dành cho thiết bị di động.\n\nBan đầu được Arianne Orpilla xây dựng cho cộng đồng học tiếng Nhật. Logo do suzy và Aaron Marbella thiết kế.\n\njidoujisho là phần mềm miễn phí và mã nguồn mở. Xem kho lưu trữ của dự án để biết danh sách đầy đủ các giấy phép khác và thông báo ghi công. Bạn thích ứng dụng này? Hãy giúp chúng tôi bằng cách gửi phản hồi, quyên góp, báo cáo sự cố hoặc đóng góp cải tiến trên GitHub.';
	@override String get same_name_dictionary_found => 'Đã tìm thấy từ điển trùng tên.';
	@override String import_file_extension_invalid({required Object extensions}) => 'Định dạng này yêu cầu tệp có một trong các phần mở rộng sau: ${extensions}';
	@override String get field_label_empty => 'Trống';
	@override String get model_to_map => 'Loại thẻ dùng cho hồ sơ mới';
	@override String get mapping_name => 'Tên hồ sơ';
	@override String get mapping_name_hint => 'Tên gán cho hồ sơ';
	@override String get error_profile_name => 'Tên hồ sơ không hợp lệ';
	@override String get error_profile_name_content => 'Hồ sơ có tên này đã tồn tại hoặc không hợp lệ nên không thể lưu.';
	@override String get error_standard_profile_name => 'Tên hồ sơ không hợp lệ';
	@override String get error_standard_profile_name_content => 'Không thể đổi tên hồ sơ tiêu chuẩn.';
	@override String get error_ankidroid_api => 'Lỗi AnkiDroid';
	@override String get error_ankidroid_api_content => 'Đã xảy ra sự cố khi giao tiếp với AnkiDroid.\n\nHãy đảm bảo dịch vụ nền của AnkiDroid đang hoạt động và mọi quyền cần thiết của ứng dụng đều đã được cấp để tiếp tục.';
	@override String get info_standard_model => 'Đã thêm loại thẻ tiêu chuẩn';
	@override String get info_standard_model_content => '『jidoujisho Kinomoto』 đã được thêm vào AnkiDroid dưới dạng loại thẻ mới.\n\nBạn có thể dùng thiết lập với loại thẻ hoặc thứ tự trường khác bằng cách thêm hồ sơ xuất mới.';
	@override String get error_model_missing => 'Thiếu loại thẻ';
	@override String get error_model_missing_content => 'Loại thẻ tương ứng với hồ sơ hiện được chọn không còn tồn tại.\n\nHồ sơ sẽ bị xóa và hồ sơ tiêu chuẩn đã được chọn thay thế.';
	@override String get error_model_changed => 'Loại thẻ đã thay đổi';
	@override String get error_model_changed_content => 'Số trường của loại thẻ tương ứng với hồ sơ đã chọn đã thay đổi.\n\nCác trường trong hồ sơ hiện được chọn đã được đặt lại và cần cấu hình lại.';
	@override String get creator_exporting_as => 'Đang tạo thẻ bằng hồ sơ';
	@override String get creator_exporting_as_fields_editing => 'Đang sửa các trường cho hồ sơ';
	@override String get creator_exporting_as_enhancements_editing => 'Đang sửa tiện ích bổ trợ cho hồ sơ';
	@override String get creator_export_card => 'Tạo thẻ';
	@override String get info_enhancements => 'Tiện ích bổ trợ tự động hóa việc chỉnh sửa trường trước khi tạo thẻ. Chọn một ô ở bên phải trường để cho phép sử dụng tiện ích bổ trợ. Mỗi trường có thể dùng tối đa năm ô bên phải. Tiện ích bổ trợ ở ô bên trái của trường sẽ tự động được áp dụng khi tạo thẻ tức thì hoặc mở Trình tạo thẻ.';
	@override String get info_actions => 'Thao tác nhanh cho phép tạo thẻ tức thì và dùng các tính năng tự động khác trên kết quả tìm kiếm từ điển. Có thể gán thao tác qua các ô bên dưới. Có thể dùng tối đa sáu ô.';
	@override String get no_more_available_enhancements => 'Không còn tiện ích bổ trợ nào cho trường này';
	@override String get no_more_available_quick_actions => 'Không còn thao tác nhanh nào';
	@override String get assign_auto_enhancement => 'Gán tiện ích bổ trợ tự động';
	@override String get assign_manual_enhancement => 'Gán tiện ích bổ trợ thủ công';
	@override String get remove_enhancement => 'Xóa tiện ích bổ trợ';
	@override String copy_of_mapping({required Object name}) => 'Bản sao của ${name}';
	@override String get enter_search_term => 'Nhập từ cần tìm...';
	@override String searching_for({required Object searchTerm}) => 'Đang tìm 『${searchTerm}』...';
	@override String get no_search_results => 'Không tìm thấy kết quả tìm kiếm.';
	@override String get edit_actions => 'Sửa thao tác nhanh của từ điển';
	@override String get remove_action => 'Xóa thao tác';
	@override String get assign_action => 'Gán thao tác';
	@override String dictionary_import_tag({required Object name}) => 'Được nhập từ ${name}';
	@override String stash_added_single({required Object term}) => 'Đã thêm 『${term}』 vào Kho tạm.';
	@override String get stash_added_multiple => 'Đã thêm nhiều mục vào Kho tạm.';
	@override String stash_clear_single({required Object term}) => 'Đã xóa 『${term}』 khỏi Kho tạm.';
	@override String get stash_clear_title => 'Xóa Kho tạm';
	@override String get stash_clear_description => 'Tất cả nội dung sẽ bị xóa. Bạn có chắc không?';
	@override String get stash_placeholder => 'Không có mục nào trong Kho tạm';
	@override String get stash_nothing_to_pop => 'Không có mục nào để lấy khỏi Kho tạm.';
	@override String get no_sentences_found => 'Không tìm thấy câu nào';
	@override String get failed_online_service => 'Không thể giao tiếp với dịch vụ trực tuyến';
	@override String get search_label_before => 'Hiện tất cả ';
	@override String get search_label_middle => 'trong số ';
	@override String get search_label_after => 'kết quả tìm kiếm cho';
	@override String get clear_dictionary_title => 'Xóa lịch sử kết quả từ điển';
	@override String get clear_dictionary_description => 'Thao tác này sẽ xóa tất cả kết quả từ điển khỏi lịch sử. Bạn có chắc không?';
	@override String get clear_search_title => 'Xóa lịch sử tìm kiếm';
	@override String get clear_search_description => 'Thao tác này sẽ xóa tất cả từ khóa tìm kiếm trong lịch sử này. Bạn có chắc không?';
	@override String get clear_creator_title => 'Xóa Trình tạo';
	@override String get clear_creator_description => 'Thao tác này sẽ xóa tất cả các trường. Bạn có chắc không?';
	@override String get copied_to_clipboard => 'Đã sao chép vào bộ nhớ tạm.';
	@override String get no_text => 'Không có văn bản.';
	@override String get info_fields => 'Các trường được điền sẵn dựa trên mục từ được chọn khi xuất tức thì hoặc trước khi mở Trình tạo thẻ. Để đưa một trường vào thẻ xuất, bạn phải bật trường đó bên dưới và gán trường trong hồ sơ xuất hiện tại. Các trường đã bật cũng có thể được thu gọn bên dưới để giảm phần rối mắt khi chỉnh sửa. Dùng nút Xóa ở góc trên bên phải của Trình tạo thẻ để nhanh chóng xóa các trường ẩn này khi chỉnh sửa thẻ thủ công.';
	@override String get edit_fields => 'Sửa và sắp xếp lại các trường';
	@override String get remove_field => 'Xóa trường';
	@override String get add_field => 'Gán trường';
	@override String get add_field_hint => 'Gán một trường cho hàng này';
	@override String get no_more_available_fields => 'Không còn trường nào';
	@override String get hidden_fields => 'Các trường bổ sung';
	@override String field_fallback_used({required Object field, required Object secondField}) => 'Trường ${field} đã dùng ${secondField} làm từ khóa tìm kiếm dự phòng.';
	@override String get no_text_to_search => 'Không có văn bản để tìm kiếm.';
	@override String get image_search_label_before => 'Đang chọn ảnh ';
	@override String get image_search_label_middle => 'trong số ';
	@override String get image_search_label_after => 'ảnh tìm thấy cho';
	@override String get image_search_label_none_middle => 'ảnh nào ';
	@override String get image_search_label_none_before => 'Chưa chọn ';
	@override String get preparing_instant_export => 'Đang chuẩn bị thẻ để xuất...';
	@override String get processing_in_progress => 'Đang chuẩn bị ảnh';
	@override String get searching_in_progress => 'Đang tìm kiếm ';
	@override String get audio_unavailable => 'Không tìm thấy âm thanh.';
	@override String get no_audio_enhancements => 'Chưa gán tiện ích bổ trợ âm thanh nào.';
	@override String card_exported({required Object deck}) => 'Đã xuất thẻ vào 『${deck}』.';
	@override String get info_incognito_on => 'Đã bật chế độ ẩn danh. Lịch sử từ điển, nội dung và tìm kiếm sẽ không được ghi lại.';
	@override String get info_incognito_off => 'Đã tắt chế độ ẩn danh. Lịch sử từ điển, nội dung và tìm kiếm sẽ được ghi lại.';
	@override String get exit_media_title => 'Thoát nội dung';
	@override String get exit_media_description => 'Bạn sẽ được đưa về menu chính. Bạn có chắc không?';
	@override String get unimplemented_source => 'Nguồn chưa được triển khai';
	@override String get clear_browser_title => 'Xóa dữ liệu trình duyệt';
	@override String get clear_browser_description => 'Thao tác này sẽ xóa tất cả dữ liệu duyệt web được các nguồn nội dung web sử dụng. Bạn có chắc không?';
	@override String get ttu_no_books_added => 'Chưa thêm sách nào vào ッツ Ebook Reader';
	@override String get local_media_directory_empty => 'Thư mục không có thư mục con hoặc video';
	@override String get pick_video_file => 'Chọn tệp video';
	@override String get navigate_up_one_directory_level => 'Lên một cấp thư mục';
	@override String get play => 'Phát';
	@override String get pause => 'Tạm dừng';
	@override String get record => 'Ghi';
	@override String get stop => 'Dừng';
	@override String get replay => 'Phát lại';
	@override String get audio_subtitles => 'Âm thanh/Phụ đề';
	@override String get player_option_shadowing => 'Chế độ shadowing';
	@override String get player_option_change_mode => 'Đổi chế độ phát';
	@override String get player_option_listening_comprehension => 'Chế độ nghe hiểu';
	@override String get player_option_drag_to_select => 'Kéo để chọn phụ đề';
	@override String get player_option_tap_to_select => 'Chạm để chọn phụ đề';
	@override String get player_option_dictionary_menu => 'Chọn nguồn từ điển đang dùng';
	@override String get player_option_cast_video => 'Truyền tới thiết bị hiển thị';
	@override String get player_option_share_subtitle => 'Chia sẻ phụ đề hiện tại';
	@override String get player_option_export => 'Tạo thẻ từ ngữ cảnh';
	@override String get player_option_audio => 'Âm thanh';
	@override String get player_option_subtitle => 'Phụ đề';
	@override String get player_option_subtitle_external => 'Bên ngoài';
	@override String get player_option_subtitle_none => 'Không có';
	@override String get player_option_select_subtitle => 'Chọn kênh phụ đề';
	@override String get player_option_select_audio => 'Chọn kênh âm thanh';
	@override String get player_option_text_filter => 'Dùng bộ lọc biểu thức chính quy';
	@override String get player_option_blur_preferences => 'Tùy chọn khung làm mờ';
	@override String get player_option_blur_use => 'Dùng khung làm mờ';
	@override String get player_option_blur_radius => 'Bán kính làm mờ';
	@override String get player_option_blur_options => 'Đặt màu và độ mờ của khung làm mờ';
	@override String get player_option_blur_reset => 'Đặt lại kích thước và vị trí khung làm mờ';
	@override String get player_align_subtitle_transcript => 'Căn phụ đề với bản chép lời';
	@override String get player_option_subtitle_appearance => 'Thời gian và giao diện phụ đề';
	@override String get player_option_load_subtitles => 'Tải phụ đề bên ngoài';
	@override String get player_option_subtitle_delay => 'Độ trễ phụ đề';
	@override String get player_option_audio_allowance => 'Thời gian đệm âm thanh';
	@override String get player_option_font_name => 'Tên phông chữ phụ đề';
	@override String get player_option_font_size => 'Cỡ chữ phụ đề';
	@override String get player_option_regex_filter => 'Bộ lọc biểu thức chính quy';
	@override String get player_option_subtitle_background_opacity => 'Độ đục nền phụ đề';
	@override String get player_option_subtitle_background_blur_radius => 'Bán kính làm mờ nền phụ đề';
	@override String get player_option_outline_width => 'Độ rộng viền phụ đề';
	@override String get player_option_subtitle_always_above_bottom_bar => 'Luôn hiển thị phụ đề phía trên khu vực thanh dưới';
	@override String get player_subtitles_transcript_empty => 'Bản chép lời trống.';
	@override String get player_prepare_export => 'Đang chuẩn bị thẻ...';
	@override String get player_change_player_orientation => 'Đổi hướng trình phát';
	@override String get no_current_media => 'Phát hoặc làm mới nội dung để xem lời bài hát';
	@override String get lyrics_permission_required => 'Chưa được cấp quyền cần thiết';
	@override String get no_lyrics_found => 'Không tìm thấy lời bài hát';
	@override String get trending => 'Thịnh hành';
	@override String get caption_filter => 'Lọc phụ đề';
	@override String get captions_query => 'Đang tìm phụ đề';
	@override String get captions_target => 'Ngôn ngữ đích';
	@override String get captions_app => 'Ngôn ngữ ứng dụng';
	@override String get captions_other => 'Ngôn ngữ khác';
	@override String get captions_closed => 'Phụ đề do người tạo';
	@override String get captions_auto => 'Phụ đề tự động';
	@override String get captions_unavailable => 'Không có phụ đề';
	@override String get captions_error => 'Lỗi khi tìm phụ đề';
	@override String get change_quality => 'Đổi chất lượng';
	@override String get closed_captions_query => 'Đang tìm phụ đề';
	@override String get closed_captions_target => 'Phụ đề ngôn ngữ đích';
	@override String get closed_captions_app => 'Phụ đề bằng ngôn ngữ ứng dụng';
	@override String get closed_captions_other => 'Phụ đề bằng ngôn ngữ khác';
	@override String get closed_captions_unavailable => 'Không có phụ đề';
	@override String get closed_captions_error => 'Lỗi khi tìm phụ đề';
	@override String get stream_url => 'URL luồng phát';
	@override String get default_option => 'Mặc định';
	@override String get paste => 'Dán';
	@override String get select_all => 'Chọn tất cả';
	@override String get lyrics_title => 'Tên bài';
	@override String get lyrics_artist => 'Nghệ sĩ';
	@override String get set_media => 'Đặt nội dung';
	@override String get no_recordings_found => 'Không tìm thấy bản ghi nào';
	@override String get wrap_image_audio => 'Thêm thẻ HTML hình ảnh/âm thanh khi xuất';
	@override String get server_address => 'Địa chỉ máy chủ';
	@override String get no_active_connection => 'Không có kết nối đang hoạt động';
	@override String get failed_server_connection => 'Không thể kết nối với máy chủ';
	@override String get no_text_received => 'Chưa nhận được văn bản';
	@override String get text_segmentation => 'Phân đoạn văn bản';
	@override String get connect_disconnect => 'Kết nối/Ngắt kết nối';
	@override String get clear_text_title => 'Xóa văn bản';
	@override String get clear_text_description => 'Thao tác này sẽ xóa tất cả văn bản đã nhận. Bạn có chắc không?';
	@override String get close_connection_title => 'Đóng kết nối';
	@override String get close_connection_description => 'Thao tác này sẽ kết thúc kết nối WebSocket và xóa tất cả văn bản đã nhận. Bạn có chắc không?';
	@override String get use_slow_import => 'Nhập chậm (dùng nếu nhập lỗi)';
	@override String get settings => 'Cài đặt';
	@override String get manager => 'Trình quản lý';
	@override String get volume_button_page_turning => 'Dùng nút âm lượng để chuyển trang';
	@override String get invert_volume_buttons => 'Đảo nút âm lượng';
	@override String get volume_button_turning_speed => 'Tốc độ cuộn liên tục';
	@override String get extend_page_beyond_navbar => 'Mở rộng trang qua thanh điều hướng';
	@override String get tweaks => 'Tinh chỉnh';
	@override String get increase => 'Tăng';
	@override String get decrease => 'Giảm';
	@override String get unit_milliseconds => 'ms';
	@override String get unit_pixels => 'px';
	@override String get dictionary_settings => 'Cài đặt từ điển';
	@override String get auto_search => 'Tìm kiếm tự động';
	@override String get auto_search_debounce_delay => 'Độ trễ trước khi tự tìm';
	@override String get dictionary_font_size => 'Cỡ chữ từ điển';
	@override String get close_on_export => 'Đóng khi xuất';
	@override String get close_on_export_on => 'Trình tạo thẻ sẽ tự động đóng sau khi xuất thẻ.';
	@override String get close_on_export_off => 'Trình tạo thẻ sẽ không còn tự động đóng sau khi xuất thẻ.';
	@override String get export_profile_empty => 'Hồ sơ xuất của bạn chưa có trường nào được đặt và cần được cấu hình.';
	@override String get error_export_media_ankidroid => 'Đã xảy ra lỗi khi xuất nội dung vào AnkiDroid.';
	@override String get error_add_note => 'Đã xảy ra lỗi khi thêm thẻ vào AnkiDroid.';
	@override String get first_time_setup => 'Thiết lập lần đầu';
	@override String get first_time_setup_description => 'Chào mừng đến với jidoujisho! Hãy đặt ngôn ngữ đích và một hồ sơ mặc định sẽ được tùy chỉnh cho bạn. Bạn có thể thay đổi tùy chọn này bất cứ lúc nào.';
	@override String get maximum_entries => 'Giới hạn tối đa số mục từ điển được truy vấn';
	@override String get maximum_terms => 'Số từ đầu mục tối đa trong kết quả';
	@override String get use_br_tags => 'Dùng <br> thay cho ký tự xuống dòng khi xuất';
	@override String get prepend_dictionary_names => 'Thêm tên từ điển vào trước nghĩa';
	@override String get highlight_on_tap => 'Tô sáng văn bản khi chạm';
	@override String get no_audio_file => 'Không có tệp âm thanh để lưu.';
	@override String get storage_permissions => 'Vui lòng cấp các quyền sau để xuất vào AnkiDroid.';
	@override String get stream => 'Luồng phát';
	@override String get network_subtitles_warning => 'Không hỗ trợ phụ đề nhúng cho luồng mạng.';
	@override String get accessibility => 'Cần có quyền để chụp văn bản từ các sự kiện hỗ trợ tiếp cận.';
	@override String get comments => 'Bình luận';
	@override String get replies => 'Phản hồi';
	@override String get no_comments_queried => 'Không tìm thấy bình luận nào';
	@override String get no_text_in_clipboard => 'Không có văn bản để hiển thị';
	@override String file_downloaded({required Object name}) => 'Đã tải tệp xuống: ${name}';
	@override String get cfhange_sort_order => 'Đổi thứ tự sắp xếp';
	@override String get login => 'Đăng nhập';
	@override String get send => 'Gửi';
	@override String get no_messages => 'Bắt đầu trò chuyện';
	@override String get enter_message => 'Nhập tin nhắn...';
	@override String get clear_message_title => 'Xóa tin nhắn';
	@override String get clear_message_description => 'Thao tác này sẽ xóa tất cả tin nhắn và bắt đầu cuộc trò chuyện mới. Bạn có chắc không?';
	@override String get error_chatgpt_response => 'Yêu cầu không thành công hoặc đã bị giới hạn tần suất. Hãy thử lại sau ít phút hoặc kiểm tra giới hạn sử dụng của bạn.';
	@override String get pick_file => 'Chọn tệp';
	@override String get open_url => 'Mở URL';
	@override String get catalogs => 'Danh mục';
	@override String get name => 'Tên';
	@override String get url => 'URL';
	@override String get duplicate_catalog => 'Đã có danh mục với URL này.';
	@override String get no_catalogs_listed => 'Không có danh mục nào';
	@override String get go_back => 'Quay lại';
	@override String get invalid_mokuro_file => 'Tệp không phải là tệp HTML do Mokuro tạo.';
	@override String get create_catalog => 'Tạo danh mục';
	@override String get adapt_ttu_theme => 'Điều chỉnh cửa sổ bật lên của từ điển theo giao diện';
	@override String get sentence_picker => 'Chọn câu';
	@override String field_locked({required Object field}) => 'Trường ${field} đã khóa và sẽ không bị xóa khi xuất trong lúc Trình tạo đang hoạt động.';
	@override String field_unlocked({required Object field}) => 'Trường ${field} đã mở khóa và sẽ bị xóa khi xuất.';
	@override String get field_lock => 'Khóa trường';
	@override String get field_unlock => 'Mở khóa trường';
	@override String get use_dark_theme => 'Dùng giao diện tối';
	@override String get stretch_to_fill_screen => 'Kéo giãn để lấp đầy màn hình';
	@override String get processing_embedded_subtitles => 'Đang xử lý phụ đề nhúng. Hãy thử lại sau.';
	@override String get transcript_playback_mode => 'Chế độ phát bản chép lời';
	@override String get toggle_transcript_background => 'Bật/tắt nền bản chép lời';
	@override String get seek => 'Tua';
	@override String get saved_tags => 'Đã lưu nhãn.';
	@override String structured_content_first({required Object i}) => '${i} định nghĩa không được hỗ trợ và đã bị lược bỏ.';
	@override String get structured_content_second => 'Hãy thử dùng phiên bản nội dung không có cấu trúc của từ điển này.';
	@override String get missing_api_key => 'Chưa cung cấp khóa API';
	@override String get chatgpt_error => 'Đã xảy ra lỗi khi nhận phản hồi từ ChatGPT.';
	@override String get api_key => 'Khóa API';
	@override String subtitle_delay_set({required Object ms}) => 'Đã đặt độ trễ phụ đề thành ${ms} ms.';
	@override String get cancel => 'Hủy';
	@override String get server_port_in_use => 'Cổng máy chủ cục bộ đang được sử dụng';
	@override String get google_fonts => 'Google Fonts';
	@override String get video_show => 'Hiện video';
	@override String get video_hide => 'Ẩn video';
	@override String get subtitle_timing_show => 'Hiện thời gian phụ đề';
	@override String get subtitle_timing_hide => 'Ẩn thời gian phụ đề';
	@override String get find_next => 'Tìm tiếp';
	@override String get find_previous => 'Tìm trước';
	@override String get shadowing_mode => 'Chế độ shadowing';
	@override String get display_settings => 'Cài đặt hiển thị';
	@override String get cloze => 'Điền chỗ trống';
	@override String get info_standard_update => 'Loại thẻ hồ sơ tiêu chuẩn mới';
	@override String get info_standard_update_content => 'Hồ sơ tiêu chuẩn hiện dùng loại thẻ 『jidoujisho Kinomoto』.\n\nHồ sơ tiêu chuẩn cũ của bạn vẫn có thể sử dụng để đảm bảo tương thích ngược.';
	@override late final _StringsRetryingInVi retrying_in = _StringsRetryingInVi._(_root);
	@override late final _StringsViewRepliesVi view_replies = _StringsViewRepliesVi._(_root);
	@override String get manage_duplicate_checks => 'Quản lý kiểm tra trùng lặp';
	@override String get playback_normal => 'Chế độ phát bình thường';
	@override String get playback_condensed => 'Chế độ phát cô đọng';
	@override String get playback_auto_pause => 'Chế độ phát tạm dừng theo phụ đề';
	@override String get player_hardware_acceleration => 'Tăng tốc phần cứng';
	@override String get player_use_opensles => 'Âm thanh OpenSL ES';
	@override String get go_forward => 'Đi tới';
	@override String get browse => 'Duyệt';
	@override String get bookmark => 'Dấu trang';
	@override String get add_bookmark => 'Thêm dấu trang';
	@override String get add_to_reading_list => 'Thêm vào danh sách đọc';
	@override String get reading_list_empty => 'Danh sách đọc trống';
	@override String get reading_list_add_toast => 'Đã thêm vào danh sách đọc.';
	@override String get reading_list_remove_toast => 'Đã xóa khỏi danh sách đọc.';
	@override String get ad_block_hosts => 'Danh sách chặn quảng cáo (hosts)';
	@override String get error_parsing_hosts_file => 'Lỗi khi phân tích tệp hosts.';
	@override String get double_tap_seek_duration => 'Thời lượng tua khi chạm hai lần';
	@override String get player_background_play => 'Phát trong nền';
	@override String get loaded_from_cache => 'Đã tải từ bộ nhớ đệm lưu trữ web.';
	@override String get player_show_subtitle_in_notification => 'Hiện phụ đề trong thông báo nội dung';
	@override String get subtitles_processing => 'Đang xử lý phụ đề...';
	@override String get video_unavailable => 'Video không khả dụng';
	@override String get video_unavailable_content => 'Không thể lấy các luồng phát. Có thể có hạn chế khiến bạn không thể xem video này.';
	@override String get video_file_error => 'Không thể tải tệp';
	@override String get video_file_error_content => 'Không thể tải tệp video. Hãy đảm bảo tệp này tồn tại và nằm trong thư mục mà ứng dụng có thể truy cập.';
	@override String get ttu_add => 'Thêm';
	@override String get ttu_add_book => 'Thêm sách';
	@override String get ttu_reader_settings => 'Cài đặt trình đọc';
	@override String get ttu_reader_source => 'Nguồn trình đọc';
	@override String get ttu_empty_title => 'Thư viện của bạn đang trống';
	@override String get ttu_empty_body => 'Thêm tệp EPUB hoặc HTMLZ để bắt đầu đọc. Chạm vào bất kỳ từ nào để tra từ khi đọc.';
	@override String get ttu_restore_backup => 'Khôi phục từ bản sao lưu';
	@override String ttu_adding_book({required Object name}) => 'Đang thêm ${name}';
	@override String ttu_adding_books({required Object n}) => 'Đang thêm ${n} sách';
	@override String get ttu_reading_file => 'ッツ đang đọc tệp';
	@override String ttu_added_book({required Object name}) => 'Đã thêm ${name}';
	@override String ttu_added_books({required Object n}) => 'Đã thêm ${n} sách';
	@override String ttu_import_failed({required Object reason}) => 'Không thể thêm sách: ${reason}';
	@override String ttu_unsupported_file({required Object name}) => '${name} không phải là tệp EPUB hoặc HTMLZ';
	@override String get ttu_shelf_error => 'Không thể đọc thư viện.';
	@override String get ttu_try_again => 'Thử lại';
	@override String ttu_book_deleted({required Object name}) => 'Đã xóa ${name}';
	@override String get ttu_undo => 'Hoàn tác';
	@override String get ttu_read => 'Đọc';
	@override String get ttu_continue => 'Tiếp tục';
	@override String get ttu_memo => 'Ghi chú';
	@override String get ttu_memos => 'Ghi chú';
	@override String get ttu_new_memo => 'Ghi chú mới';
	@override String get ttu_edit_memo => 'Sửa ghi chú';
	@override String get ttu_memo_placeholder => 'Một từ cần tra, một câu hỏi, lý do dòng này quan trọng';
	@override String ttu_memo_saved({required Object position}) => 'Đã lưu ghi chú tại ${position}';
	@override String get ttu_memo_deleted => 'Đã xóa ghi chú';
	@override String get ttu_no_memos => 'Chưa có ghi chú. Chọn văn bản trong sách rồi chạm vào Ghi chú để thêm.';
	@override String get ttu_no_memos_short => 'Chưa có ghi chú';
	@override String get ttu_memo_hint => 'Thêm ghi chú khi đọc: chọn văn bản rồi chạm vào Ghi chú.';
	@override String get ttu_continue_reading => 'Đọc tiếp';
	@override String get ttu_back_to_where => 'Quay lại vị trí trước đó';
	@override String get ttu_before_jump => 'trước lần chuyển cuối';
	@override String get ttu_sort_position => 'Vị trí';
	@override String get ttu_sort_newest => 'Mới nhất';
	@override String ttu_read_percent({required Object percent}) => 'Đã đọc ${percent}';
	@override String get ttu_edit => 'Sửa';
	@override String get ttu_delete => 'Xóa';
	@override String get ttu_progress => 'Tiến độ';
	@override String get ttu_read_label => 'Đã đọc';
	@override String ttu_of_total({required Object total}) => 'trên ${total}';
	@override String get ttu_last_opened => 'Mở lần cuối';
	@override String get ttu_not_opened => 'Chưa mở';
	@override String ttu_added_when({required Object when}) => 'Đã thêm ${when}';
	@override String get ttu_language => 'Ngôn ngữ';
	@override String get ttu_uses_dictionaries => 'Tra từ bằng ngôn ngữ này';
	@override String get ttu_page => 'Trang';
	@override String get ttu_page_note => 'ッツ áp dụng các cài đặt này khi mở sách';
	@override String ttu_books_in({required Object language}) => 'Sách bằng ${language}';
	@override String get ttu_theme => 'Chủ đề';
	@override String get ttu_text_size => 'Cỡ chữ';
	@override String get ttu_direction => 'Hướng chữ';
	@override String get ttu_vertical => 'Dọc';
	@override String get ttu_horizontal => 'Ngang';
	@override String get ttu_layout => 'Bố cục';
	@override String get ttu_pages => 'Trang';
	@override String get ttu_scroll => 'Cuộn';
	@override String get ttu_furigana => 'Hiện Furigana';
	@override String get ttu_furigana_desc => 'Cách đọc bên trên kanji, nếu sách có';
	@override String get ttu_while_reading => 'Khi đọc';
	@override String get ttu_auto_save => 'Lưu vị trí của tôi';
	@override String get ttu_auto_save_desc => 'Lưu khi bạn đọc và khi bạn rời khỏi sách';
	@override String get ttu_highlight => 'Tô sáng từ đã tra';
	@override String get ttu_highlight_desc => 'Đánh dấu từ mà từ điển đã tra';
	@override String get ttu_volume => 'Phím âm lượng chuyển trang';
	@override String get ttu_volume_desc => 'Mỗi lần nhấn chuyển một trang';
	@override String get ttu_volume_swap => 'Đổi phím âm lượng';
	@override String get ttu_volume_swap_desc => 'Nếu các phím hoạt động ngược chiều';
	@override String get ttu_scroll_step => 'Bước cuộn';
	@override String get ttu_scroll_step_desc => 'Khoảng cuộn sau mỗi lần nhấn phím trong bố cục Cuộn';
	@override String get ttu_full_screen => 'Toàn màn hình';
	@override String get ttu_full_screen_desc => 'Hiển thị bên dưới thanh trạng thái. Phù hợp nhất với điện thoại không có tai thỏ';
	@override String get ttu_match_popup => 'Cửa sổ bật lên khớp với trang';
	@override String get ttu_match_popup_desc => 'Dùng chủ đề của trang cho cửa sổ bật lên';
	@override String get ttu_more => 'Thêm';
	@override String get ttu_backup_sync => 'Sao lưu và đồng bộ';
	@override String get ttu_backup_sync_desc => 'Google Drive, OneDrive hoặc một thư mục. Mở ッツ';
	@override String get ttu_all_settings => 'Tất cả cài đặt ッツ';
	@override String get ttu_all_settings_desc => 'Phông chữ, lề, cột trang và nhiều cài đặt khác. Mở ッツ';
	@override String get ttu_opening => 'Đang mở';
	@override String get ttu_jumping_to => 'Đang chuyển đến';
	@override String get ttu_returning_to => 'Quay lại';
	@override String ttu_back_to({required Object position}) => 'Quay lại ${position}';
	@override String ttu_saved_place({required Object position}) => 'Đã lưu vị trí của bạn tại ${position}';
	@override String get ttu_just_now => 'Vừa xong';
	@override String ttu_minutes_ago({required Object n}) => '${n} phút trước';
	@override String get ttu_today => 'Hôm nay';
	@override String get ttu_yesterday => 'Hôm qua';
	@override String ttu_days_ago({required Object n}) => '${n} ngày trước';
	@override String get ttu_week_ago => '1 tuần trước';
	@override String ttu_weeks_ago({required Object n}) => '${n} tuần trước';
	@override String get ttu_month_ago => '1 tháng trước';
	@override String ttu_months_ago({required Object n}) => '${n} tháng trước';
	@override String get my_words => 'Mục từ của tôi';
	@override String get my_words_add => 'Thêm vào Mục từ của tôi';
	@override String get my_words_edit => 'Sửa mục từ';
	@override String get my_words_word => 'Mục từ';
	@override String get my_words_reading => 'Cách đọc';
	@override String get my_words_meaning => 'Nghĩa (tùy chọn)';
	@override String get my_words_meaning_hint => 'Tạo sinh tăng cường truy xuất';
	@override String get my_words_saved => 'Đã lưu vào Mục từ của tôi';
	@override String get my_words_deleted => 'Đã xóa mục từ';
	@override String get my_words_empty => 'Chưa có mục từ';
	@override String get my_words_info => 'Nghĩa do bạn tự thêm. Chúng luôn hiển thị đầu tiên mỗi khi bạn tra mục từ, trong bất kỳ cuốn sách nào. Chọn văn bản như "software as a service (SaaS)" rồi chạm vào Thêm mục từ để lưu SaaS chỉ với một lần chạm.';
	@override String get my_words_new => 'Mục từ mới';
	@override String get add_word => 'Thêm mục từ';
	@override String get ttu_page_info => 'Sách bằng ngôn ngữ này sẽ mở với các cài đặt này.';
	@override String get ttu_font => 'Phông chữ';
	@override String get ttu_font_serif => 'Serif';
	@override String get ttu_font_sans => 'Sans';
	@override String get ttu_font_mincho => 'Mincho';
	@override String get ttu_font_klee => 'Klee';
	@override String get ttu_line_spacing => 'Giãn dòng';
	@override String get ttu_margins => 'Lề';
	@override String get ttu_columns => 'Cột';
	@override String get ttu_columns_auto => 'Tự động';
	@override String get ttu_furigana_label => 'Furigana';
	@override String get ttu_furigana_show => 'Hiện';
	@override String get ttu_furigana_faded => 'Mờ';
	@override String get ttu_furigana_hidden => 'Ẩn';
	@override String get ttu_furigana_tap => 'Khi chạm';
	@override String get ttu_furigana_info => 'Mờ hiển thị cách đọc bằng màu xám. Khi chạm hiển thị cách đọc lúc bạn chạm vào một từ.';
	@override String get ttu_avoid_break => 'Giữ nguyên đoạn văn';
	@override String get ttu_avoid_break_info => 'Chuyển đoạn văn sang trang tiếp theo thay vì chia đoạn.';
	@override String get ttu_blur_images => 'Làm mờ hình ảnh';
	@override String get ttu_blur_images_info => 'Ẩn hình ảnh sau lớp che spoiler cho đến khi bạn chạm vào chúng.';
	@override String get ttu_full_screen_info => 'Ẩn thanh trạng thái và thanh điều hướng. Khi vuốt từ cạnh màn hình, chúng chỉ hiện ra, vì vậy bạn cần vuốt hai lần để thoát hoặc mở thông báo.';
	@override String get ttu_camera_area => 'Dùng vùng camera';
	@override String get ttu_camera_area_info => 'Cho phép trang hiển thị bên dưới phần khoét camera.';
	@override String get ttu_keep_screen_on => 'Giữ màn hình luôn bật';
	@override String get ttu_auto_save_info => 'Lưu khi bạn đọc và khi bạn rời khỏi sách.';
	@override String get ttu_match_popup_info => 'Dùng chủ đề của trang cho cửa sổ tra từ bật lên.';
	@override String get ttu_scroll_step_info => 'Khoảng cuộn sau mỗi lần nhấn phím trong bố cục Cuộn.';
	@override String get file_access_title => 'Cho phép truy cập tệp?';
	@override String get file_access_media => 'Ảnh, video và âm thanh';
	@override String get file_access_all => 'Tất cả tệp';
	@override String get file_access_allow => 'Cho phép';
	@override String get file_access_not_now => 'Để sau';
	@override String get file_access_info => 'Cần quyền này để mở video và manga từ các thư mục trên điện thoại. Ảnh, video và âm thanh là đủ để phát video; Tất cả tệp cũng tìm thấy các tệp phụ đề bên cạnh chúng. Sách và từ điển không bao giờ cần quyền này.';
	@override String get file_access_info_short => 'Cần quyền này để mở video và manga từ các thư mục trên điện thoại. Sách và từ điển không bao giờ cần quyền này.';
	@override String get file_access_denied => 'Không thể mở tệp nếu chưa được cấp quyền truy cập. Bạn có thể cho phép trong phần cài đặt Android.';
	@override String ttu_language_changed({required Object language}) => 'Các từ trong sách này hiện được tra bằng ${language}';
	@override String my_terms_from({required Object title}) => 'Từ ${title}';
	@override String my_terms_saved_term({required Object term}) => 'Đã lưu ${term}';
	@override String get my_terms_edit => 'Sửa';
	@override String get ttu_terms => 'Mục từ';
	@override String get ttu_no_terms => 'Chưa có mục từ nào được lưu từ sách này';
	@override String ttu_place_kept({required Object position}) => 'Vị trí của bạn vẫn là ${position}';
	@override String get ttu_read_on => 'Đọc';
	@override String get ttu_font_genei => 'Genei';
	@override String get ttu_chapters => 'Chương';
	@override String get ttu_no_chapters => 'Sách này không có danh sách chương';
	@override String get ttu_applying => 'Đang áp dụng cài đặt';
	@override String get ttu_memos_on_page => 'Hiện ghi chú trên trang';
	@override String get ttu_memos_on_page_info => 'Một dòng ngắn phía trên mỗi đoạn văn có ghi chú. Chạm vào để đọc toàn bộ ghi chú.';
	@override String get ttu_color_amber => 'Hổ phách';
	@override String get ttu_color_rose => 'Hồng';
	@override String get ttu_color_green => 'Xanh lá';
	@override String get ttu_color_sky => 'Xanh dương';
	@override String get ttu_color_violet => 'Tím';
	@override String get catalog_title => 'Từ điển trực tuyến';
	@override String get catalog_open => 'Trực tuyến';
	@override String get catalog_connect_title => 'Kết nối máy chủ từ điển';
	@override String get catalog_connect_hint => 'Dán địa chỉ máy chủ và token. Token chỉ đọc cho phép duyệt và tải xuống; token quản trị còn cho phép tải lên và xóa. Dán liên kết có token sau dấu # sẽ tự điền cả hai.';
	@override String get catalog_address => 'Địa chỉ máy chủ';
	@override String get catalog_token => 'Token';
	@override String get catalog_connect => 'Kết nối';
	@override String get catalog_all => 'Tất cả';
	@override String get catalog_section_bilingual => 'Song ngữ';
	@override String get catalog_section_monolingual => 'Đơn ngữ';
	@override String get catalog_section_kanji => 'Kanji';
	@override String get catalog_section_frequency => 'Tần suất';
	@override String get catalog_section_pronunciation => 'Phát âm';
	@override String get catalog_section_other => 'Khác';
	@override String catalog_entries({required Object n}) => '${n} mục từ';
	@override String get catalog_installed => 'Đã cài đặt';
	@override String get catalog_preparing => 'Đang chuẩn bị';
	@override String get catalog_failed => 'Không thể chuẩn bị';
	@override String get catalog_download => 'Tải xuống';
	@override String get catalog_search_hint => 'Tìm trong từ điển này';
	@override String catalog_nothing_found({required Object query}) => 'Không tìm thấy gì cho ${query}';
	@override String get catalog_upload => 'Tải lên';
	@override String catalog_uploading({required Object name}) => 'Đang tải ${name} lên';
	@override String catalog_uploaded({required Object name}) => '${name} đã có trên máy chủ và đang được chuẩn bị';
	@override String get catalog_replace => 'Thay thế';
	@override String get catalog_delete => 'Xóa khỏi máy chủ';
	@override String get catalog_delete_confirm => 'Chạm lần nữa để xóa';
	@override String catalog_deleted({required Object name}) => 'Đã xóa ${name} khỏi máy chủ';
	@override String get catalog_words => 'Từ';
	@override String get catalog_definitions => 'Định nghĩa';
	@override String get catalog_languages_hint => 'Ngôn ngữ bạn tra từ và ngôn ngữ của phần định nghĩa. Các từ điển không có thông tin này trong chỉ mục sẽ được máy chủ gắn nhãn dựa trên nội dung; hãy sửa tại đây nếu máy chủ đoán sai.';
	@override String get catalog_save => 'Lưu';
	@override String get catalog_server => 'Máy chủ';
	@override String get catalog_disconnect => 'Ngắt kết nối';
	@override String get catalog_role_admin => 'Quản trị viên';
	@override String get catalog_role_read => 'Chỉ đọc';
	@override String get catalog_empty => 'Chưa có từ điển nào trên máy chủ';
	@override String catalog_imported({required Object name}) => 'Đã nhập ${name}';
	@override String get catalog_unknown_language => 'Không xác định';
	@override String get backup_title => 'Sao lưu và khôi phục';
	@override String get backup_menu => 'Sao lưu và khôi phục';
	@override String get backup_step_settings => 'Cài đặt';
	@override String get backup_step_memos => 'Ghi chú và mục từ';
	@override String backup_step_books({required Object language}) => 'Sách (${language})';
	@override String backup_step_dictionary({required Object name}) => 'Từ điển: ${name}';
	@override String get backup_step_packing => 'Đang đóng gói';
	@override String backup_step_download({required Object name}) => 'Đang tải ${name} xuống';
	@override String backup_step_install({required Object name}) => 'Đang cài đặt ${name}';
	@override String get backup_not_a_backup => 'Tệp này không phải bản sao lưu jidoujisho.';
	@override String get backup_too_new => 'Bản sao lưu này được tạo bởi phiên bản ứng dụng mới hơn. Hãy cập nhật ứng dụng để khôi phục.';
	@override String get backup_make => 'Sao lưu';
	@override String get backup_make_hint => 'Một tệp chứa sách và vị trí đọc, cài đặt và phông chữ của ッツ, ghi chú, Mục từ của tôi, lịch sử, hồ sơ Anki, cài đặt ứng dụng cùng liên kết máy chủ từ điển và các từ điển của bạn. Khi khôi phục, các từ điển có trên máy chủ từ điển sẽ được tải xuống lại; các từ điển khác được lưu trong tệp. Tệp có chứa token máy chủ của bạn, hãy giữ kín tệp này.';
	@override String get backup_restore => 'Khôi phục';
	@override String get backup_restore_hint => 'Thay thế sách, ghi chú, mục từ và cài đặt trên thiết bị này bằng dữ liệu trong bản sao lưu. Các từ điển đã có trên thiết bị vẫn được giữ lại; những từ điển khác trong bản sao lưu sẽ được cài đặt.';
	@override String get backup_choose => 'Chọn bản sao lưu';
	@override String get backup_saved => 'Đã lưu bản sao lưu';
	@override String get backup_not_saved => 'Chưa lưu được bản sao lưu';
	@override String get backup_books => 'Sách';
	@override String get backup_dictionaries => 'Từ điển';
	@override String backup_dictionaries_split({required Object included, required Object online}) => '${included} trong tệp · ${online} từ máy chủ của bạn';
	@override String get backup_memos => 'Ghi chú';
	@override String get backup_terms => 'Mục từ của tôi';
	@override String backup_made({required Object date, required Object version}) => 'Được tạo ${date} bằng ${version}';
	@override String get backup_restore_confirm => 'Chạm lần nữa để thay thế dữ liệu trên thiết bị này';
	@override String get backup_restored => 'Đã khôi phục. Khởi động lại ứng dụng để hoàn tất.';
	@override String get backup_restart => 'Đóng ứng dụng';
	@override String backup_failed_dictionaries({required Object names}) => 'Không thể cài đặt: ${names}';
	@override String get backup_working => 'Hãy giữ ứng dụng mở cho đến khi hoàn tất.';
	@override String get theme_menu => 'Chủ đề';
	@override String get theme_mode => 'Chế độ';
	@override String get theme_mode_system => 'Hệ thống';
	@override String get theme_mode_light => 'Sáng';
	@override String get theme_mode_dark => 'Tối';
	@override String get theme_mode_hint => 'Hệ thống làm theo điện thoại của bạn và chuyển đổi cùng điện thoại.';
	@override String get theme_accent => 'Màu nhấn';
	@override String get theme_accent_red => 'Đỏ';
	@override String get theme_accent_rose => 'Hồng';
	@override String get theme_accent_orange => 'Cam';
	@override String get theme_accent_green => 'Xanh lá';
	@override String get theme_accent_teal => 'Xanh ngọc';
	@override String get theme_accent_blue => 'Xanh dương';
	@override String get theme_accent_violet => 'Tím';
	@override String get theme_accent_slate => 'Xám xanh';
	@override String get ttu_search => 'Tìm kiếm';
	@override String get ttu_search_hint => 'Tìm trong sách này';
	@override String ttu_search_found({required Object count}) => 'Tìm thấy ${count} kết quả';
	@override String ttu_search_first({required Object shown}) => 'Hiển thị ${shown} kết quả đầu tiên';
	@override String get ttu_search_none => 'Không có trong sách này';
	@override String get ttu_search_reading => 'Đang đọc sách…';
	@override String get ttu_search_stay => 'Ở lại đây';
	@override String get ttu_search_list => 'Tất cả kết quả';
	@override String get ttu_search_previous => 'Kết quả trước';
	@override String get ttu_search_next => 'Kết quả tiếp theo';
	@override String get ttu_search_info => 'Kết quả không phân biệt hiragana và katakana, ký tự full-width và half-width, hay chữ hoa và chữ thường. Không tìm kiếm Furigana. Vị trí đã lưu vẫn giữ nguyên cho đến khi bạn chọn Ở lại đây.';
	@override String get ttu_favourite => 'Yêu thích';
	@override String get ttu_unfavourite => 'Xóa khỏi mục yêu thích';
	@override String get ttu_favourites => 'Mục yêu thích';
	@override String get ttu_shelf => 'Kệ sách';
	@override String get ttu_group_by => 'Nhóm theo';
	@override String get ttu_group_by_none => 'Không nhóm';
	@override String get ttu_group_by_groups => 'Nhóm của tôi';
	@override String get ttu_group_by_language => 'Ngôn ngữ';
	@override String get ttu_group_by_progress => 'Tiến độ';
	@override String get ttu_group => 'Nhóm';
	@override String get ttu_group_none => 'Không có';
	@override String get ttu_ungrouped => 'Chưa thuộc nhóm';
	@override String get ttu_progress_reading => 'Đang đọc';
	@override String get ttu_progress_unread => 'Chưa bắt đầu';
	@override String get ttu_progress_finished => 'Đã đọc xong';
	@override String get ttu_other_books => 'Sách';
	@override String get ttu_new_group => 'Nhóm mới';
	@override String get ttu_group_name => 'Tên nhóm';
	@override String get ttu_rename_group => 'Đổi tên';
	@override String get ttu_delete_group => 'Xóa nhóm';
	@override String get ttu_group_info => 'Sách sẽ hiển thị dưới nhóm khi kệ sách được nhóm theo Nhóm của tôi trong phần cài đặt kệ sách.';
	@override String get ttu_group_by_info => 'Mục yêu thích luôn hiển thị đầu tiên. Chạm vào tiêu đề để thu gọn.';
	@override String get ttu_this_book => 'Sách này';
	@override String get ttu_follow_links => 'Mở liên kết';
	@override String get ttu_follow_links_info => 'Khi bật, chạm vào liên kết sẽ đưa bạn đến nơi liên kết trỏ tới, kèm cách quay lại. Khi tắt, liên kết được đọc như văn bản thường và chạm vào sẽ tra từ.';
	@override String get ttu_book_fonts => 'Phông chữ riêng của sách';
	@override String get ttu_book_fonts_info => 'Khi tắt, phông chữ của bạn được dùng cho toàn bộ sách. Mã vẫn dùng phông chữ đơn cách.';
	@override String ttu_repaired_partly({required Object title}) => 'Một phần của ${title} bị thiếu trong tệp. Phần còn lại đã được thêm.';
	@override String get catalog_description => 'Mô tả';
	@override String get catalog_description_hint => 'Dùng để làm gì hoặc dành cho ai';
	@override String catalog_description_shown_in({required Object language}) => 'Chỉ hiển thị khi ứng dụng dùng ${language}';
	@override String import_replacing({required Object name}) => 'Đang thay thế ${name} cũ…';
	@override String get catalog_update => 'Cập nhật lên phiên bản này';
	@override String get dictionary_about => 'Thông tin';
	@override String dictionary_by({required Object author}) => 'Tác giả: ${author}';
	@override String get dictionary_delete_all => 'Xóa tất cả từ điển';
	@override String get dictionary_import => 'Nhập';
	@override String get dictionary_collapsed => 'Mặc định thu gọn';
	@override String get dictionary_show_in_results => 'Hiện trong kết quả';
	@override String get dictionary_start_collapsed => 'Thu gọn sẵn trong kết quả';
	@override String get dictionary_from_server => 'Đã tải xuống';
	@override String get dictionary_from_file => 'Đã nhập từ tệp';
	@override String get dictionary_delete => 'Xóa từ điển';
	@override String get ttu_add_font => 'Thêm phông chữ';
	@override String get ttu_font_unsupported => 'Phông chữ phải là tệp .ttf, .otf, .woff hoặc .woff2.';
	@override String get ttu_font_failed => 'Không thể thêm phông chữ.';
	@override String ttu_remove_font({required Object name}) => 'Xóa ${name}';
	@override String get auto_backup_title => 'Luôn cập nhật bản sao lưu';
	@override String get auto_backup_hint => 'Một tệp sao lưu ở nơi bạn chọn, chẳng hạn như Google Drive, sẽ được ghi đè khi đến hạn để chỉ giữ lại bản mới nhất. Tệp được cập nhật khi ứng dụng đang mở, một lúc sau khi bạn mở ứng dụng.';
	@override String get auto_backup_choose => 'Chọn nơi lưu';
	@override String get auto_backup_file => 'Tệp sao lưu';
	@override String get auto_backup_daily => 'Mỗi ngày';
	@override String get auto_backup_weekly => 'Mỗi tuần';
	@override String get auto_backup_own_dictionaries => 'Bao gồm các từ điển do tôi tự thêm';
	@override String get auto_backup_own_dictionaries_info => 'Các từ điển này có thể khiến tệp lớn. Từ điển trên máy chủ của bạn luôn được liệt kê và sẽ được tải xuống lại khi khôi phục.';
	@override String get auto_backup_now => 'Cập nhật ngay';
	@override String get auto_backup_off => 'Tắt';
	@override String auto_backup_updated({required Object date}) => 'Đã cập nhật ${date}';
	@override String get auto_backup_never => 'Chưa cập nhật';
	@override String auto_backup_failed({required Object reason}) => 'Lần cập nhật cuối thất bại: ${reason}';
	@override String get auto_backup_lost => 'Không thể truy cập tệp sao lưu nữa. Hãy chọn lại nơi lưu.';
	@override String get auto_backup_writing => 'Đang ghi tệp sao lưu';
	@override String get auto_backup_cannot_keep => 'Sau này không thể ghi lại vào nơi đó. Hãy chọn nơi khác, chẳng hạn như một thư mục hoặc Google Drive.';
	@override String get auto_backup_running => 'Đang cập nhật tệp sao lưu';
	@override String get ttu_tags => 'Nhãn';
	@override String get ttu_add_tag => 'Thêm nhãn';
	@override String get ttu_tags_none => 'Chưa có nhãn';
	@override String get ttu_tags_used_before => 'Đã dùng trước đây';
	@override String get ttu_tags_info => 'Nhãn hiển thị trên bìa sách. Chọn một nhãn đã dùng trước đây hoặc nhập nhãn mới.';
	@override late final _StringsTtuThemeNamesVi ttu_theme_names = _StringsTtuThemeNamesVi._(_root);
	@override late final _StringsLanguageNamesVi language_names = _StringsLanguageNamesVi._(_root);
	@override late final _StringsAddonsVi addons = _StringsAddonsVi._(_root);
}

// Path: retrying_in
class _StringsRetryingInVi extends _StringsRetryingInEn {
	_StringsRetryingInVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String seconds({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('vi'))(n,
		one: 'Đang thử lại sau ${n} giây...',
		other: 'Đang thử lại sau ${n} giây...',
	);
}

// Path: view_replies
class _StringsViewRepliesVi extends _StringsViewRepliesEn {
	_StringsViewRepliesVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String reply({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('vi'))(n,
		one: 'HIỆN ${n} PHẢN HỒI',
		other: 'HIỆN ${n} PHẢN HỒI',
	);
}

// Path: ttu_theme_names
class _StringsTtuThemeNamesVi extends _StringsTtuThemeNamesEn {
	_StringsTtuThemeNamesVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get light => 'Sáng';
	@override String get ecru => 'Ngà';
	@override String get water => 'Nước';
	@override String get gray => 'Xám';
	@override String get dark => 'Tối';
	@override String get black => 'Đen';
}

// Path: language_names
class _StringsLanguageNamesVi extends _StringsLanguageNamesEn {
	_StringsLanguageNamesVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get ja => 'Tiếng Nhật';
	@override String get en => 'Tiếng Anh';
	@override String get vi => 'Tiếng Việt';
	@override String get zh => 'Tiếng Trung';
	@override String get ko => 'Tiếng Hàn';
	@override String get fr => 'Tiếng Pháp';
	@override String get de => 'Tiếng Đức';
	@override String get es => 'Tiếng Tây Ban Nha';
	@override String get ru => 'Tiếng Nga';
	@override String get th => 'Tiếng Thái';
	@override String get ar => 'Tiếng Ả Rập';
}

// Path: addons
class _StringsAddonsVi extends _StringsAddonsEn {
	_StringsAddonsVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override late final _StringsAddonsFieldVi field = _StringsAddonsFieldVi._(_root);
	@override late final _StringsAddonsEnhancementVi enhancement = _StringsAddonsEnhancementVi._(_root);
	@override late final _StringsAddonsActionVi action = _StringsAddonsActionVi._(_root);
	@override late final _StringsAddonsSourceVi source = _StringsAddonsSourceVi._(_root);
}

// Path: addons.field
class _StringsAddonsFieldVi extends _StringsAddonsFieldEn {
	_StringsAddonsFieldVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override late final _StringsAddonsFieldSentenceVi sentence = _StringsAddonsFieldSentenceVi._(_root);
	@override late final _StringsAddonsFieldTermVi term = _StringsAddonsFieldTermVi._(_root);
	@override late final _StringsAddonsFieldReadingVi reading = _StringsAddonsFieldReadingVi._(_root);
	@override late final _StringsAddonsFieldMeaningVi meaning = _StringsAddonsFieldMeaningVi._(_root);
	@override late final _StringsAddonsFieldNotesVi notes = _StringsAddonsFieldNotesVi._(_root);
	@override late final _StringsAddonsFieldImageVi image = _StringsAddonsFieldImageVi._(_root);
	@override late final _StringsAddonsFieldAudioVi audio = _StringsAddonsFieldAudioVi._(_root);
	@override late final _StringsAddonsFieldAudioSentenceVi audio_sentence = _StringsAddonsFieldAudioSentenceVi._(_root);
	@override late final _StringsAddonsFieldPitchAccentVi pitch_accent = _StringsAddonsFieldPitchAccentVi._(_root);
	@override late final _StringsAddonsFieldFuriganaVi furigana = _StringsAddonsFieldFuriganaVi._(_root);
	@override late final _StringsAddonsFieldFrequencyVi frequency = _StringsAddonsFieldFrequencyVi._(_root);
	@override late final _StringsAddonsFieldContextVi context = _StringsAddonsFieldContextVi._(_root);
	@override late final _StringsAddonsFieldClozeBeforeVi cloze_before = _StringsAddonsFieldClozeBeforeVi._(_root);
	@override late final _StringsAddonsFieldClozeInsideVi cloze_inside = _StringsAddonsFieldClozeInsideVi._(_root);
	@override late final _StringsAddonsFieldClozeAfterVi cloze_after = _StringsAddonsFieldClozeAfterVi._(_root);
	@override late final _StringsAddonsFieldExpandedMeaningVi expanded_meaning = _StringsAddonsFieldExpandedMeaningVi._(_root);
	@override late final _StringsAddonsFieldCollapsedMeaningVi collapsed_meaning = _StringsAddonsFieldCollapsedMeaningVi._(_root);
	@override late final _StringsAddonsFieldHiddenMeaningVi hidden_meaning = _StringsAddonsFieldHiddenMeaningVi._(_root);
	@override late final _StringsAddonsFieldTagsVi tags = _StringsAddonsFieldTagsVi._(_root);
}

// Path: addons.enhancement
class _StringsAddonsEnhancementVi extends _StringsAddonsEnhancementEn {
	_StringsAddonsEnhancementVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override late final _StringsAddonsEnhancementClearFieldVi clear_field = _StringsAddonsEnhancementClearFieldVi._(_root);
	@override late final _StringsAddonsEnhancementJpd101AudioVi jpd101_audio = _StringsAddonsEnhancementJpd101AudioVi._(_root);
	@override late final _StringsAddonsEnhancementForvoAudioVi forvo_audio = _StringsAddonsEnhancementForvoAudioVi._(_root);
	@override late final _StringsAddonsEnhancementPickAudioVi pick_audio = _StringsAddonsEnhancementPickAudioVi._(_root);
	@override late final _StringsAddonsEnhancementAudioRecorderVi audio_recorder = _StringsAddonsEnhancementAudioRecorderVi._(_root);
	@override late final _StringsAddonsEnhancementOpenStashVi open_stash = _StringsAddonsEnhancementOpenStashVi._(_root);
	@override late final _StringsAddonsEnhancementPopFromStashVi pop_from_stash = _StringsAddonsEnhancementPopFromStashVi._(_root);
	@override late final _StringsAddonsEnhancementTextSegmentationVi text_segmentation = _StringsAddonsEnhancementTextSegmentationVi._(_root);
	@override late final _StringsAddonsEnhancementBingImagesSearchVi bing_images_search = _StringsAddonsEnhancementBingImagesSearchVi._(_root);
	@override late final _StringsAddonsEnhancementCropImageVi crop_image = _StringsAddonsEnhancementCropImageVi._(_root);
	@override late final _StringsAddonsEnhancementPickImageVi pick_image = _StringsAddonsEnhancementPickImageVi._(_root);
	@override late final _StringsAddonsEnhancementCameraVi camera = _StringsAddonsEnhancementCameraVi._(_root);
	@override late final _StringsAddonsEnhancementSentencePickerVi sentence_picker = _StringsAddonsEnhancementSentencePickerVi._(_root);
	@override late final _StringsAddonsEnhancementSearchDictionaryVi search_dictionary = _StringsAddonsEnhancementSearchDictionaryVi._(_root);
	@override late final _StringsAddonsEnhancementMassifExampleSentencesVi massif_example_sentences = _StringsAddonsEnhancementMassifExampleSentencesVi._(_root);
	@override late final _StringsAddonsEnhancementTatoebaExampleSentencesVi tatoeba_example_sentences = _StringsAddonsEnhancementTatoebaExampleSentencesVi._(_root);
	@override late final _StringsAddonsEnhancementImmersionKitVi immersion_kit = _StringsAddonsEnhancementImmersionKitVi._(_root);
	@override late final _StringsAddonsEnhancementSaveTagsVi save_tags = _StringsAddonsEnhancementSaveTagsVi._(_root);
}

// Path: addons.action
class _StringsAddonsActionVi extends _StringsAddonsActionEn {
	_StringsAddonsActionVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override late final _StringsAddonsActionCardCreatorVi card_creator = _StringsAddonsActionCardCreatorVi._(_root);
	@override late final _StringsAddonsActionInstantExportVi instant_export = _StringsAddonsActionInstantExportVi._(_root);
	@override late final _StringsAddonsActionAddToStashVi add_to_stash = _StringsAddonsActionAddToStashVi._(_root);
	@override late final _StringsAddonsActionMyWordsVi my_words = _StringsAddonsActionMyWordsVi._(_root);
	@override late final _StringsAddonsActionCopyToClipboardVi copy_to_clipboard = _StringsAddonsActionCopyToClipboardVi._(_root);
	@override late final _StringsAddonsActionShareVi share = _StringsAddonsActionShareVi._(_root);
	@override late final _StringsAddonsActionPlayAudioVi play_audio = _StringsAddonsActionPlayAudioVi._(_root);
}

// Path: addons.source
class _StringsAddonsSourceVi extends _StringsAddonsSourceEn {
	_StringsAddonsSourceVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override late final _StringsAddonsSourcePlayerLocalMediaVi player_local_media = _StringsAddonsSourcePlayerLocalMediaVi._(_root);
	@override late final _StringsAddonsSourcePlayerYoutubeVi player_youtube = _StringsAddonsSourcePlayerYoutubeVi._(_root);
	@override late final _StringsAddonsSourcePlayerNetworkStreamVi player_network_stream = _StringsAddonsSourcePlayerNetworkStreamVi._(_root);
	@override late final _StringsAddonsSourceReaderTtuVi reader_ttu = _StringsAddonsSourceReaderTtuVi._(_root);
	@override late final _StringsAddonsSourceReaderMokuroVi reader_mokuro = _StringsAddonsSourceReaderMokuroVi._(_root);
	@override late final _StringsAddonsSourceReaderBrowserVi reader_browser = _StringsAddonsSourceReaderBrowserVi._(_root);
	@override late final _StringsAddonsSourceReaderLyricsVi reader_lyrics = _StringsAddonsSourceReaderLyricsVi._(_root);
	@override late final _StringsAddonsSourceReaderChatgptVi reader_chatgpt = _StringsAddonsSourceReaderChatgptVi._(_root);
	@override late final _StringsAddonsSourceReaderClipboardVi reader_clipboard = _StringsAddonsSourceReaderClipboardVi._(_root);
	@override late final _StringsAddonsSourceReaderWebsocketVi reader_websocket = _StringsAddonsSourceReaderWebsocketVi._(_root);
	@override late final _StringsAddonsSourceViewerCameraVi viewer_camera = _StringsAddonsSourceViewerCameraVi._(_root);
}

// Path: addons.field.sentence
class _StringsAddonsFieldSentenceVi extends _StringsAddonsFieldSentenceEn {
	_StringsAddonsFieldSentenceVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Câu';
	@override String get description => 'Phụ đề, đoạn trích trong sách và thông tin ngữ cảnh khác.';
}

// Path: addons.field.term
class _StringsAddonsFieldTermVi extends _StringsAddonsFieldTermEn {
	_StringsAddonsFieldTermVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Mục từ';
	@override String get description => 'Từ đầu mục hoặc cụm từ trong từ điển.';
}

// Path: addons.field.reading
class _StringsAddonsFieldReadingVi extends _StringsAddonsFieldReadingEn {
	_StringsAddonsFieldReadingVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Cách đọc';
	@override String get description => 'Cách phát âm hoặc kiểu nói.';
}

// Path: addons.field.meaning
class _StringsAddonsFieldMeaningVi extends _StringsAddonsFieldMeaningEn {
	_StringsAddonsFieldMeaningVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Nghĩa';
	@override String get description => 'Tất cả định nghĩa trong từ điển của một mục từ.';
}

// Path: addons.field.notes
class _StringsAddonsFieldNotesVi extends _StringsAddonsFieldNotesEn {
	_StringsAddonsFieldNotesVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Ghi chú';
	@override String get description => 'Thông tin bổ sung hoặc nhận xét cá nhân.';
}

// Path: addons.field.image
class _StringsAddonsFieldImageVi extends _StringsAddonsFieldImageEn {
	_StringsAddonsFieldImageVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Hình ảnh';
	@override String get description => 'Thông tin bổ sung trực quan. Có thể dùng trường văn bản để nhập từ tìm kiếm cho các nguồn hình ảnh.';
}

// Path: addons.field.audio
class _StringsAddonsFieldAudioVi extends _StringsAddonsFieldAudioEn {
	_StringsAddonsFieldAudioVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Âm thanh mục từ';
	@override String get description => 'Âm thanh liên quan đến mục từ. Có thể dùng trường văn bản để nhập từ tìm kiếm cho các nguồn âm thanh.';
}

// Path: addons.field.audio_sentence
class _StringsAddonsFieldAudioSentenceVi extends _StringsAddonsFieldAudioSentenceEn {
	_StringsAddonsFieldAudioSentenceVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Âm thanh câu';
	@override String get description => 'Âm thanh liên quan đến câu. Có thể dùng trường văn bản để nhập từ tìm kiếm cho các nguồn âm thanh.';
}

// Path: addons.field.pitch_accent
class _StringsAddonsFieldPitchAccentVi extends _StringsAddonsFieldPitchAccentEn {
	_StringsAddonsFieldPitchAccentVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Trọng âm cao độ';
	@override String get description => 'Điền sẵn văn bản để xuất sơ đồ trọng âm cao độ.';
}

// Path: addons.field.furigana
class _StringsAddonsFieldFuriganaVi extends _StringsAddonsFieldFuriganaEn {
	_StringsAddonsFieldFuriganaVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Furigana';
	@override String get description => 'Điền sẵn văn bản để xuất Furigana.';
}

// Path: addons.field.frequency
class _StringsAddonsFieldFrequencyVi extends _StringsAddonsFieldFrequencyEn {
	_StringsAddonsFieldFrequencyVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Tần suất';
	@override String get description => 'Thêm tần suất của từ đầu mục để sắp xếp, được tính bằng trung bình điều hòa.';
}

// Path: addons.field.context
class _StringsAddonsFieldContextVi extends _StringsAddonsFieldContextEn {
	_StringsAddonsFieldContextVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Ngữ cảnh';
	@override String get description => 'Tên của nguồn hiện tại.';
}

// Path: addons.field.cloze_before
class _StringsAddonsFieldClozeBeforeVi extends _StringsAddonsFieldClozeBeforeEn {
	_StringsAddonsFieldClozeBeforeVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Trước chỗ trống';
	@override String get description => 'Văn bản trước phần được tô sáng trong câu. Trống nếu không có gì được tô sáng.';
}

// Path: addons.field.cloze_inside
class _StringsAddonsFieldClozeInsideVi extends _StringsAddonsFieldClozeInsideEn {
	_StringsAddonsFieldClozeInsideVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Chỗ trống';
	@override String get description => 'Văn bản được tô sáng trong câu.';
}

// Path: addons.field.cloze_after
class _StringsAddonsFieldClozeAfterVi extends _StringsAddonsFieldClozeAfterEn {
	_StringsAddonsFieldClozeAfterVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Sau chỗ trống';
	@override String get description => 'Văn bản sau phần được tô sáng trong câu. Trống nếu không có gì được tô sáng.';
}

// Path: addons.field.expanded_meaning
class _StringsAddonsFieldExpandedMeaningVi extends _StringsAddonsFieldExpandedMeaningEn {
	_StringsAddonsFieldExpandedMeaningVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Nghĩa mở rộng';
	@override String get description => 'Chỉ các định nghĩa từ những từ điển đang mở rộng.';
}

// Path: addons.field.collapsed_meaning
class _StringsAddonsFieldCollapsedMeaningVi extends _StringsAddonsFieldCollapsedMeaningEn {
	_StringsAddonsFieldCollapsedMeaningVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Nghĩa thu gọn';
	@override String get description => 'Chỉ các định nghĩa từ những từ điển đang thu gọn.';
}

// Path: addons.field.hidden_meaning
class _StringsAddonsFieldHiddenMeaningVi extends _StringsAddonsFieldHiddenMeaningEn {
	_StringsAddonsFieldHiddenMeaningVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Nghĩa ẩn';
	@override String get description => 'Chỉ các định nghĩa từ những từ điển đang ẩn.';
}

// Path: addons.field.tags
class _StringsAddonsFieldTagsVi extends _StringsAddonsFieldTagsEn {
	_StringsAddonsFieldTagsVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Nhãn';
	@override String get description => 'Sắp xếp thẻ trong bộ thẻ bằng các nhãn cách nhau bởi dấu cách.';
}

// Path: addons.enhancement.clear_field
class _StringsAddonsEnhancementClearFieldVi extends _StringsAddonsEnhancementClearFieldEn {
	_StringsAddonsEnhancementClearFieldVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Xóa trường';
	@override String get description => 'Nhanh chóng xóa nội dung của một trường.';
}

// Path: addons.enhancement.jpd101_audio
class _StringsAddonsEnhancementJpd101AudioVi extends _StringsAddonsEnhancementJpd101AudioEn {
	_StringsAddonsEnhancementJpd101AudioVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Âm thanh JapanesePod101';
	@override String get description => 'Tìm cách phát âm phù hợp của từ trên JapanesePod101.';
}

// Path: addons.enhancement.forvo_audio
class _StringsAddonsEnhancementForvoAudioVi extends _StringsAddonsEnhancementForvoAudioEn {
	_StringsAddonsEnhancementForvoAudioVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Âm thanh Forvo';
	@override String get description => 'Lấy âm thanh của từ từ Forvo.';
}

// Path: addons.enhancement.pick_audio
class _StringsAddonsEnhancementPickAudioVi extends _StringsAddonsEnhancementPickAudioEn {
	_StringsAddonsEnhancementPickAudioVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Chọn âm thanh';
	@override String get description => 'Chọn tệp âm thanh bằng trình chọn bên ngoài.';
}

// Path: addons.enhancement.audio_recorder
class _StringsAddonsEnhancementAudioRecorderVi extends _StringsAddonsEnhancementAudioRecorderEn {
	_StringsAddonsEnhancementAudioRecorderVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Trình ghi âm';
	@override String get description => 'Ghi và sử dụng âm thanh thu từ micrô của thiết bị.';
}

// Path: addons.enhancement.open_stash
class _StringsAddonsEnhancementOpenStashVi extends _StringsAddonsEnhancementOpenStashEn {
	_StringsAddonsEnhancementOpenStashVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Mở Kho tạm';
	@override String get description => 'Xem và quản lý văn bản đã lưu trong Kho tạm.';
}

// Path: addons.enhancement.pop_from_stash
class _StringsAddonsEnhancementPopFromStashVi extends _StringsAddonsEnhancementPopFromStashEn {
	_StringsAddonsEnhancementPopFromStashVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Lấy từ Kho tạm';
	@override String get description => 'Nhanh chóng lấy mục mới nhất trong Kho tạm.';
}

// Path: addons.enhancement.text_segmentation
class _StringsAddonsEnhancementTextSegmentationVi extends _StringsAddonsEnhancementTextSegmentationEn {
	_StringsAddonsEnhancementTextSegmentationVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Tách văn bản';
	@override String get description => 'Tìm kiếm hoặc chọn một mục từ mới trong văn bản đã được tách.';
}

// Path: addons.enhancement.bing_images_search
class _StringsAddonsEnhancementBingImagesSearchVi extends _StringsAddonsEnhancementBingImagesSearchEn {
	_StringsAddonsEnhancementBingImagesSearchVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Tìm hình ảnh trên Bing';
	@override String get description => 'Tìm hình ảnh trên Bing bằng truy vấn hình ảnh hiện tại hoặc từ hiện tại.';
}

// Path: addons.enhancement.crop_image
class _StringsAddonsEnhancementCropImageVi extends _StringsAddonsEnhancementCropImageEn {
	_StringsAddonsEnhancementCropImageVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Cắt hình ảnh';
	@override String get description => 'Cắt hình ảnh hiện được chọn.';
}

// Path: addons.enhancement.pick_image
class _StringsAddonsEnhancementPickImageVi extends _StringsAddonsEnhancementPickImageEn {
	_StringsAddonsEnhancementPickImageVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Chọn hình ảnh';
	@override String get description => 'Chọn hình ảnh mới bằng trình chọn bên ngoài.';
}

// Path: addons.enhancement.camera
class _StringsAddonsEnhancementCameraVi extends _StringsAddonsEnhancementCameraEn {
	_StringsAddonsEnhancementCameraVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Máy ảnh';
	@override String get description => 'Chụp ảnh mới để dùng làm hình ảnh.';
}

// Path: addons.enhancement.sentence_picker
class _StringsAddonsEnhancementSentencePickerVi extends _StringsAddonsEnhancementSentencePickerEn {
	_StringsAddonsEnhancementSentencePickerVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Chọn câu';
	@override String get description => 'Chọn các câu được phân cách bằng dấu câu và khoảng trắng.';
}

// Path: addons.enhancement.search_dictionary
class _StringsAddonsEnhancementSearchDictionaryVi extends _StringsAddonsEnhancementSearchDictionaryEn {
	_StringsAddonsEnhancementSearchDictionaryVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Tra từ điển';
	@override String get description => 'Tìm trong từ điển bằng nội dung của một trường.';
}

// Path: addons.enhancement.massif_example_sentences
class _StringsAddonsEnhancementMassifExampleSentencesVi extends _StringsAddonsEnhancementMassifExampleSentencesEn {
	_StringsAddonsEnhancementMassifExampleSentencesVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Câu ví dụ từ Massif';
	@override String get description => 'Lấy các câu ví dụ được tuyển chọn qua Massif.';
}

// Path: addons.enhancement.tatoeba_example_sentences
class _StringsAddonsEnhancementTatoebaExampleSentencesVi extends _StringsAddonsEnhancementTatoebaExampleSentencesEn {
	_StringsAddonsEnhancementTatoebaExampleSentencesVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Câu ví dụ từ Tatoeba';
	@override String get description => 'Chọn cụm từ và câu ví dụ từ Tatoeba.';
}

// Path: addons.enhancement.immersion_kit
class _StringsAddonsEnhancementImmersionKitVi extends _StringsAddonsEnhancementImmersionKitEn {
	_StringsAddonsEnhancementImmersionKitVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'ImmersionKit';
	@override String get description => 'Lấy các câu ví dụ kèm hình ảnh và âm thanh.';
}

// Path: addons.enhancement.save_tags
class _StringsAddonsEnhancementSaveTagsVi extends _StringsAddonsEnhancementSaveTagsEn {
	_StringsAddonsEnhancementSaveTagsVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Lưu nhãn';
	@override String get description => 'Lưu văn bản hiện tại vào trường Nhãn.';
}

// Path: addons.action.card_creator
class _StringsAddonsActionCardCreatorVi extends _StringsAddonsActionCardCreatorEn {
	_StringsAddonsActionCardCreatorVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Trình tạo thẻ';
	@override String get description => 'Tạo thẻ từ mục từ điển đã chọn và chỉnh sửa trước khi xuất.';
}

// Path: addons.action.instant_export
class _StringsAddonsActionInstantExportVi extends _StringsAddonsActionInstantExportEn {
	_StringsAddonsActionInstantExportVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Xuất ngay';
	@override String get description => 'Xuất thẻ ngay từ mục từ điển đã chọn.';
}

// Path: addons.action.add_to_stash
class _StringsAddonsActionAddToStashVi extends _StringsAddonsActionAddToStashEn {
	_StringsAddonsActionAddToStashVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Thêm vào Kho tạm';
	@override String get description => 'Nhanh chóng lưu từ đầu mục của một mục từ điển vào Kho tạm.';
}

// Path: addons.action.my_words
class _StringsAddonsActionMyWordsVi extends _StringsAddonsActionMyWordsEn {
	_StringsAddonsActionMyWordsVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Mục từ của tôi';
	@override String get description => 'Viết nghĩa riêng của bạn cho một mục từ. Nghĩa này luôn hiển thị đầu tiên mỗi khi bạn tra mục từ.';
}

// Path: addons.action.copy_to_clipboard
class _StringsAddonsActionCopyToClipboardVi extends _StringsAddonsActionCopyToClipboardEn {
	_StringsAddonsActionCopyToClipboardVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Sao chép vào bộ nhớ tạm';
	@override String get description => 'Sao chép từ đầu mục của một mục từ điển vào bộ nhớ tạm.';
}

// Path: addons.action.share
class _StringsAddonsActionShareVi extends _StringsAddonsActionShareEn {
	_StringsAddonsActionShareVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Chia sẻ';
	@override String get description => 'Chia sẻ thông tin của một mục từ điển.';
}

// Path: addons.action.play_audio
class _StringsAddonsActionPlayAudioVi extends _StringsAddonsActionPlayAudioEn {
	_StringsAddonsActionPlayAudioVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Phát âm thanh';
	@override String get description => 'Thử phát âm thanh bằng các tiện ích bổ trợ của trường Âm thanh. Tiện ích tự động được ưu tiên trước.';
}

// Path: addons.source.player_local_media
class _StringsAddonsSourcePlayerLocalMediaVi extends _StringsAddonsSourcePlayerLocalMediaEn {
	_StringsAddonsSourcePlayerLocalMediaVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Phương tiện trên thiết bị';
	@override String get description => 'Phát video từ bộ nhớ trên thiết bị.';
}

// Path: addons.source.player_youtube
class _StringsAddonsSourcePlayerYoutubeVi extends _StringsAddonsSourcePlayerYoutubeEn {
	_StringsAddonsSourcePlayerYoutubeVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'YouTube';
	@override String get description => 'Tìm kiếm và xem video từ YouTube.';
}

// Path: addons.source.player_network_stream
class _StringsAddonsSourcePlayerNetworkStreamVi extends _StringsAddonsSourcePlayerNetworkStreamEn {
	_StringsAddonsSourcePlayerNetworkStreamVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Luồng mạng';
	@override String get description => 'Phát trực tuyến video từ URL trực tiếp.';
}

// Path: addons.source.reader_ttu
class _StringsAddonsSourceReaderTtuVi extends _StringsAddonsSourceReaderTtuEn {
	_StringsAddonsSourceReaderTtuVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'ッツ Ebook Reader';
	@override String get description => 'Đọc EPUB và tạo thẻ từ câu qua trình đọc web tích hợp.';
}

// Path: addons.source.reader_mokuro
class _StringsAddonsSourceReaderMokuroVi extends _StringsAddonsSourceReaderMokuroEn {
	_StringsAddonsSourceReaderMokuroVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Mokuro';
	@override String get description => 'Đọc các tập manga đã được xử lý thành một tệp HTML duy nhất bằng Mokuro.';
}

// Path: addons.source.reader_browser
class _StringsAddonsSourceReaderBrowserVi extends _StringsAddonsSourceReaderBrowserEn {
	_StringsAddonsSourceReaderBrowserVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Trình duyệt';
	@override String get description => 'Duyệt trang web bằng trình duyệt cho phép tìm kiếm và tạo thẻ từ văn bản đã chọn.';
}

// Path: addons.source.reader_lyrics
class _StringsAddonsSourceReaderLyricsVi extends _StringsAddonsSourceReaderLyricsEn {
	_StringsAddonsSourceReaderLyricsVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Lời bài hát';
	@override String get description => 'Cho phép lấy và tô sáng lời bài hát của phương tiện đang phát, được lấy từ Google và Uta-Net.';
}

// Path: addons.source.reader_chatgpt
class _StringsAddonsSourceReaderChatgptVi extends _StringsAddonsSourceReaderChatgptEn {
	_StringsAddonsSourceReaderChatgptVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'ChatGPT';
	@override String get description => 'Cho phép người dùng tương tác với mô hình ngôn ngữ AI bằng khóa API chính thức từ OpenAI.';
}

// Path: addons.source.reader_clipboard
class _StringsAddonsSourceReaderClipboardVi extends _StringsAddonsSourceReaderClipboardEn {
	_StringsAddonsSourceReaderClipboardVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Bộ nhớ tạm';
	@override String get description => 'Cho phép hiển thị văn bản được dán từ bộ nhớ tạm dưới dạng văn bản có thể chọn.';
}

// Path: addons.source.reader_websocket
class _StringsAddonsSourceReaderWebsocketVi extends _StringsAddonsSourceReaderWebsocketEn {
	_StringsAddonsSourceReaderWebsocketVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'WebSocket';
	@override String get description => 'Chọn văn bản nhận được từ máy chủ WebSocket và tạo thẻ từ đó.';
}

// Path: addons.source.viewer_camera
class _StringsAddonsSourceViewerCameraVi extends _StringsAddonsSourceViewerCameraEn {
	_StringsAddonsSourceViewerCameraVi._(_StringsVi root) : this._root = root, super._(root);

	@override final _StringsVi _root; // ignore: unused_field

	// Translations
	@override String get label => 'Máy ảnh';
	@override String get description => 'Xem hình ảnh được chụp bằng máy ảnh hoặc được chọn từ phương tiện.';
}

/// Flat map(s) containing all translations.
/// Only for edge cases! For simple maps, use the map function of this library.

extension on _StringsEn {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'dictionary_media_type': return 'Dictionary';
			case 'player_media_type': return 'Player';
			case 'reader_media_type': return 'Reader';
			case 'viewer_media_type': return 'Viewer';
			case 'back': return 'Back';
			case 'search': return 'Search';
			case 'search_ellipsis': return 'Search...';
			case 'show_more': return 'Show More';
			case 'show_menu': return 'Show Menu';
			case 'stash': return 'Stash';
			case 'pick_image': return 'Pick Image';
			case 'undo': return 'Undo';
			case 'copy': return 'Copy';
			case 'clear': return 'Clear';
			case 'creator': return 'Creator';
			case 'share': return 'Share';
			case 'resume_last_media': return 'Resume Last Media';
			case 'change_source': return 'Change Source';
			case 'launch_source': return 'Launch Source';
			case 'card_creator': return 'Card Creator';
			case 'target_language': return 'Target language';
			case 'show_options': return 'Show Options';
			case 'switch_profiles': return 'Switch Profiles';
			case 'dictionaries': return 'Dictionaries';
			case 'enhancements': return 'Enhancements';
			case 'app_locale': return 'App locale';
			case 'app_locale_warning': return 'Community addons and enhancements are managed by their respective developers, and these may appear in their original language.';
			case 'dialog_play': return 'PLAY';
			case 'dialog_read': return 'READ';
			case 'dialog_view': return 'VIEW';
			case 'dialog_edit': return 'EDIT';
			case 'dialog_export': return 'EXPORT';
			case 'dialog_import': return 'IMPORT';
			case 'dialog_close': return 'CLOSE';
			case 'dialog_clear': return 'CLEAR';
			case 'dialog_create': return 'CREATE';
			case 'dialog_delete': return 'DELETE';
			case 'dialog_cancel': return 'CANCEL';
			case 'dialog_select': return 'SELECT';
			case 'dialog_stash': return 'STASH';
			case 'dialog_search': return 'SEARCH';
			case 'dialog_exit': return 'EXIT';
			case 'dialog_share': return 'SHARE';
			case 'dialog_pop': return 'POP';
			case 'dialog_save': return 'SAVE';
			case 'dialog_set': return 'SET';
			case 'dialog_browse': return 'BROWSE';
			case 'dialog_channel': return 'CHANNEL';
			case 'dialog_directory': return 'DIRECTORY';
			case 'dialog_crop': return 'CROP';
			case 'dialog_connect': return 'CONNECT';
			case 'dialog_append': return 'APPEND';
			case 'dialog_record': return 'RECORD';
			case 'dialog_manage': return 'MANAGE';
			case 'dialog_stop': return 'STOP';
			case 'dialog_done': return 'DONE';
			case 'reset': return 'Reset';
			case 'dialog_launch_ankidroid': return 'LAUNCH ANKIDROID';
			case 'media_item_delete_confirmation': return 'This will clear this item from history. Are you sure you want to do this?';
			case 'dictionaries_delete_confirmation': return 'Deleting a dictionary will also clear all dictionary results from history. Are you sure you want to do this?';
			case 'mappings_delete_confirmation': return 'This profile will be deleted. Are you sure you want to do this?';
			case 'catalog_delete_confirmation': return 'This catalog will be deleted. Are you sure you want to do this?';
			case 'dictionaries_deleting_data': return 'Deleting dictionary data...';
			case 'dictionaries_menu_empty': return 'Import a dictionary for use';
			case 'options_theme_light': return 'Use light theme';
			case 'options_theme_dark': return 'Use dark theme';
			case 'options_incognito_on': return 'Turn on incognito mode';
			case 'options_incognito_off': return 'Turn off incognito mode';
			case 'options_dictionaries': return 'Manage dictionaries';
			case 'options_profiles': return 'Export profiles';
			case 'options_enhancements': return 'User enhancements';
			case 'options_language': return 'Language settings';
			case 'options_github': return 'View repository on GitHub';
			case 'options_attribution': return 'Licenses and attribution';
			case 'options_copy': return 'Copy';
			case 'options_collapse': return 'Collapse';
			case 'options_expand': return 'Expand';
			case 'options_delete': return 'Delete';
			case 'options_show': return 'Show';
			case 'options_hide': return 'Hide';
			case 'options_edit': return 'Edit';
			case 'info_empty_home_tab': return 'History is empty';
			case 'delete_in_progress': return 'Delete in progress';
			case 'import_format': return 'Import format';
			case 'import_in_progress': return 'Import in progress';
			case 'import_start': return 'Preparing for import...';
			case 'import_clean': return 'Cleaning working space...';
			case 'import_extract_count': return ({required Object n}) => 'Extracted ${n} files...';
			case 'import_extract': return 'Extracting files...';
			case 'import_name': return ({required Object name}) => 'Importing 『${name}』...';
			case 'import_entries': return 'Processing entries...';
			case 'import_found_entry': return ({required Object count}) => 'Found ${count} entries...';
			case 'import_found_tag': return ({required Object count}) => 'Found ${count} tags...';
			case 'import_found_frequency': return ({required Object count}) => 'Found ${count} frequency entries...';
			case 'import_found_pitch': return ({required Object count}) => 'Found ${count} pitch accent entries...';
			case 'import_write_entry': return ({required Object count, required Object total}) => 'Writing entries:\n${count} / ${total}';
			case 'import_write_tag': return ({required Object count, required Object total}) => 'Writing tags:\n${count} / ${total}';
			case 'import_write_frequency': return ({required Object count, required Object total}) => 'Writing frequency entries:\n${count} / ${total}';
			case 'import_write_pitch': return ({required Object count, required Object total}) => 'Writing pitch accent entries:\n${count} / ${total}';
			case 'import_failed': return 'Dictionary import failed.';
			case 'import_complete': return 'Dictionary import complete.';
			case 'import_duplicate': return ({required Object name}) => 'A dictionary with the name『${name}』is already imported.';
			case 'dialog_title_dictionary_clear': return 'Clear all dictionaries?';
			case 'dialog_content_dictionary_clear': return 'Wiping the dictionary database will also clear all search results in history.';
			case 'dialog_title_dictionary_delete': return ({required Object name}) => 'Delete 『${name}』?';
			case 'dialog_content_dictionary_delete': return 'Deleting a single dictionary may take longer than clearing the entire dictionary database. This will also clear all search results in history.';
			case 'delete_dictionary_data': return 'Clearing all dictionary data...';
			case 'dictionary_tag': return ({required Object name}) => 'Imported from ${name}';
			case 'legalese': return 'A full-featured immersion language learning suite for mobile.\n\nOriginally built for the Japanese language learning community by Arianne Orpilla. Logo by suzy and Aaron Marbella.\n\njidoujisho is free and open source software. See the project repository for a comprehensive list of other licenses and attribution notices. Enjoying the application? Help out by providing feedback, making a donation, reporting issues or contributing improvements on GitHub.';
			case 'same_name_dictionary_found': return 'Dictionary with same name found.';
			case 'import_file_extension_invalid': return ({required Object extensions}) => 'This format expects files with the following extensions: ${extensions}';
			case 'field_label_empty': return 'Empty';
			case 'model_to_map': return 'Card type to use for new profile';
			case 'mapping_name': return 'Profile name';
			case 'mapping_name_hint': return 'Name to assign to profile';
			case 'error_profile_name': return 'Invalid profile name';
			case 'error_profile_name_content': return 'A profile with this name already exists or is not valid and cannot be saved.';
			case 'error_standard_profile_name': return 'Invalid profile name';
			case 'error_standard_profile_name_content': return 'Cannot rename the standard profile.';
			case 'error_ankidroid_api': return 'AnkiDroid error';
			case 'error_ankidroid_api_content': return 'There was an issue communicating with AnkiDroid.\n\nEnsure that the AnkiDroid background service is active and all relevant app permissions are granted in order to continue.';
			case 'info_standard_model': return 'Standard card type added';
			case 'info_standard_model_content': return '『jidoujisho Kinomoto』 has been added to AnkiDroid as a new card type.\n\nSetups making use of a different card type or field order may be used by adding a new export profile.';
			case 'error_model_missing': return 'Missing card type';
			case 'error_model_missing_content': return 'The corresponding card type of the currently selected profile is missing.\n\nThe profile will be deleted, and the standard profile has now been selected in its place.';
			case 'error_model_changed': return 'Card type changed';
			case 'error_model_changed_content': return 'The number of fields of the card type corresponding to the selected profile has changed.\n\nThe fields of the currently selected profile have been reset and will require reconfiguration.';
			case 'creator_exporting_as': return 'Creating card with profile';
			case 'creator_exporting_as_fields_editing': return 'Editing fields for profile';
			case 'creator_exporting_as_enhancements_editing': return 'Editing enhancements for profile';
			case 'creator_export_card': return 'Create Card';
			case 'info_enhancements': return 'Enhancements enable the automation of field editing prior to card creation. Pick a slot on the right of a field to allow use of an enhancement. Up to five right slots may be utilised for each field. The enhancement in the left slot of a field will be automatically applied in instant card creation or upon launch of the Card Creator.';
			case 'info_actions': return 'Quick actions allow for instant card creation and other automations to be used on dictionary search results. Actions can be assigned via the slots below. Up to six slots may be utilised.';
			case 'no_more_available_enhancements': return 'No more available enhancements for this field';
			case 'no_more_available_quick_actions': return 'No more available quick actions';
			case 'assign_auto_enhancement': return 'Assign Auto Enhancement';
			case 'assign_manual_enhancement': return 'Assign Manual Enhancement';
			case 'remove_enhancement': return 'Remove Enhancement';
			case 'copy_of_mapping': return ({required Object name}) => 'Copy of ${name}';
			case 'enter_search_term': return 'Enter a search term...';
			case 'searching_for': return ({required Object searchTerm}) => 'Searching for 『${searchTerm}』...';
			case 'no_search_results': return 'No search results found.';
			case 'edit_actions': return 'Edit Dictionary Quick Actions';
			case 'remove_action': return 'Remove Action';
			case 'assign_action': return 'Assign Action';
			case 'dictionary_import_tag': return ({required Object name}) => 'Imported from ${name}';
			case 'stash_added_single': return ({required Object term}) => '『${term}』has been added to the Stash.';
			case 'stash_added_multiple': return 'Multiple items have been added to the Stash.';
			case 'stash_clear_single': return ({required Object term}) => '『${term}』has been removed from the Stash.';
			case 'stash_clear_title': return 'Clear Stash';
			case 'stash_clear_description': return 'All contents will be cleared. Are you sure?';
			case 'stash_placeholder': return 'No items in the Stash';
			case 'stash_nothing_to_pop': return 'No items to be popped from the Stash.';
			case 'no_sentences_found': return 'No sentences found';
			case 'failed_online_service': return 'Failed to communicate with online service';
			case 'search_label_before': return 'Show all ';
			case 'search_label_middle': return 'out of ';
			case 'search_label_after': return 'search results found for';
			case 'clear_dictionary_title': return 'Clear Dictionary Result History';
			case 'clear_dictionary_description': return 'This will clear all dictionary results from history. Are you sure?';
			case 'clear_search_title': return 'Clear Search History';
			case 'clear_search_description': return 'This will clear all search terms for this history. Are you sure?';
			case 'clear_creator_title': return 'Clear Creator';
			case 'clear_creator_description': return 'This will clear all fields. Are you sure?';
			case 'copied_to_clipboard': return 'Copied to clipboard.';
			case 'no_text': return 'No text.';
			case 'info_fields': return 'Fields are pre-filled based on the term selected on instant export or prior to opening the Card Creator. In order to include a field for card export, it must be enabled below as well as mapped in the current selected export profile. Enabled fields may also be collapsed below in order to reduce clutter during editing. Use the Clear button on the top-right of the Card Creator in order to wipe these hidden fields quickly when manually editing a card.';
			case 'edit_fields': return 'Edit and Reorder Fields';
			case 'remove_field': return 'Remove Field';
			case 'add_field': return 'Assign Field';
			case 'add_field_hint': return 'Assign a field to this row';
			case 'no_more_available_fields': return 'No more available fields';
			case 'hidden_fields': return 'Additional fields';
			case 'field_fallback_used': return ({required Object field, required Object secondField}) => 'The ${field} field used ${secondField} as its fallback search term.';
			case 'no_text_to_search': return 'No text to search.';
			case 'image_search_label_before': return 'Selecting image ';
			case 'image_search_label_middle': return 'out of ';
			case 'image_search_label_after': return 'found for';
			case 'image_search_label_none_middle': return 'no image ';
			case 'image_search_label_none_before': return 'Selecting ';
			case 'preparing_instant_export': return 'Preparing card for export...';
			case 'processing_in_progress': return 'Preparing images';
			case 'searching_in_progress': return 'Searching for ';
			case 'audio_unavailable': return 'No audio could be found.';
			case 'no_audio_enhancements': return 'No audio enhancements are assigned.';
			case 'card_exported': return ({required Object deck}) => 'Card exported to 『${deck}』.';
			case 'info_incognito_on': return 'Incognito mode on. Dictionary, media and search history will not be tracked.';
			case 'info_incognito_off': return 'Incognito mode off. Dictionary, media and search history will be tracked.';
			case 'exit_media_title': return 'Exit Media';
			case 'exit_media_description': return 'This will return you to the main menu. Are you sure?';
			case 'unimplemented_source': return 'Unimplemented source';
			case 'clear_browser_title': return 'Clear Browser Data';
			case 'clear_browser_description': return 'This will clear all browsing data used in media sources that use web content. Are you sure?';
			case 'ttu_no_books_added': return 'No books added to ッツ Ebook Reader';
			case 'local_media_directory_empty': return 'Directory has no folders or video';
			case 'pick_video_file': return 'Pick Video File';
			case 'navigate_up_one_directory_level': return 'Navigate Up One Directory Level';
			case 'play': return 'Play';
			case 'pause': return 'Pause';
			case 'record': return 'Record';
			case 'stop': return 'Stop';
			case 'replay': return 'Replay';
			case 'audio_subtitles': return 'Audio/Subtitles';
			case 'player_option_shadowing': return 'Shadowing Mode';
			case 'player_option_change_mode': return 'Change Playback Mode';
			case 'player_option_listening_comprehension': return 'Listening Comprehension Mode';
			case 'player_option_drag_to_select': return 'Use Drag to Select Subtitle Selection';
			case 'player_option_tap_to_select': return 'Use Tap to Select Subtitle Selection';
			case 'player_option_dictionary_menu': return 'Select Active Dictionary Source';
			case 'player_option_cast_video': return 'Cast to Display Device';
			case 'player_option_share_subtitle': return 'Share Current Subtitle';
			case 'player_option_export': return 'Create Card from Context';
			case 'player_option_audio': return 'Audio';
			case 'player_option_subtitle': return 'Subtitle';
			case 'player_option_subtitle_external': return 'External';
			case 'player_option_subtitle_none': return 'None';
			case 'player_option_select_subtitle': return 'Select Subtitle Track';
			case 'player_option_select_audio': return 'Select Audio Track';
			case 'player_option_text_filter': return 'Use Regular Expression Filter';
			case 'player_option_blur_preferences': return 'Blur Widget Preferences';
			case 'player_option_blur_use': return 'Use Blur Widget';
			case 'player_option_blur_radius': return 'Blur radius';
			case 'player_option_blur_options': return 'Set Blur Widget Color and Bluriness';
			case 'player_option_blur_reset': return 'Reset Blur Widget Size and Position';
			case 'player_align_subtitle_transcript': return 'Align Subtitle with Transcript';
			case 'player_option_subtitle_appearance': return 'Subtitle Timing and Appearance';
			case 'player_option_load_subtitles': return 'Load External Subtitles';
			case 'player_option_subtitle_delay': return 'Subtitle delay';
			case 'player_option_audio_allowance': return 'Audio allowance';
			case 'player_option_font_name': return 'Subtitle font name';
			case 'player_option_font_size': return 'Subtitle font size';
			case 'player_option_regex_filter': return 'Regular expression filter';
			case 'player_option_subtitle_background_opacity': return 'Subtitle background opacity';
			case 'player_option_subtitle_background_blur_radius': return 'Subtitle background blur radius';
			case 'player_option_outline_width': return 'Subtitle outline width';
			case 'player_option_subtitle_always_above_bottom_bar': return 'Always show subtitle above bottom bar area';
			case 'player_subtitles_transcript_empty': return 'Transcript is empty.';
			case 'player_prepare_export': return 'Preparing card...';
			case 'player_change_player_orientation': return 'Change Player Orientation';
			case 'no_current_media': return 'Play or refresh media for lyrics';
			case 'lyrics_permission_required': return 'Required permission not granted';
			case 'no_lyrics_found': return 'No lyrics found';
			case 'trending': return 'Trending';
			case 'caption_filter': return 'Filter Closed Captions';
			case 'captions_query': return 'Querying for captions';
			case 'captions_target': return 'Target language';
			case 'captions_app': return 'App language';
			case 'captions_other': return 'Other language';
			case 'captions_closed': return 'Closed captioning';
			case 'captions_auto': return 'Automatic captioning';
			case 'captions_unavailable': return 'No captioning';
			case 'captions_error': return 'Error while querying captions';
			case 'change_quality': return 'Change Quality';
			case 'closed_captions_query': return 'Querying for captions';
			case 'closed_captions_target': return 'Target language captions';
			case 'closed_captions_app': return 'App language captions';
			case 'closed_captions_other': return 'Other language captions';
			case 'closed_captions_unavailable': return 'No captions';
			case 'closed_captions_error': return 'Error while querying captions';
			case 'stream_url': return 'Stream URL';
			case 'default_option': return 'Default';
			case 'paste': return 'Paste';
			case 'select_all': return 'Select all';
			case 'lyrics_title': return 'Title';
			case 'lyrics_artist': return 'Artist';
			case 'set_media': return 'Set Media';
			case 'no_recordings_found': return 'No recordings found';
			case 'wrap_image_audio': return 'Include image/audio HTML tags on export';
			case 'server_address': return 'Server Address';
			case 'no_active_connection': return 'No active connection';
			case 'failed_server_connection': return 'Failed to connect to server';
			case 'no_text_received': return 'No text received';
			case 'text_segmentation': return 'Text Segmentation';
			case 'connect_disconnect': return 'Connect/Disconnect';
			case 'clear_text_title': return 'Clear Text';
			case 'clear_text_description': return 'This will clear all received text. Are you sure?';
			case 'close_connection_title': return 'Close Connection';
			case 'close_connection_description': return 'This will end the WebSocket connection and clear all received text. Are you sure?';
			case 'use_slow_import': return 'Slow import (use if failing)';
			case 'settings': return 'Settings';
			case 'manager': return 'Manager';
			case 'volume_button_page_turning': return 'Volume button page turning';
			case 'invert_volume_buttons': return 'Invert volume buttons';
			case 'volume_button_turning_speed': return 'Continuous scrolling speed';
			case 'extend_page_beyond_navbar': return 'Extend page beyond navigation bar';
			case 'tweaks': return 'Tweaks';
			case 'increase': return 'Increase';
			case 'decrease': return 'Decrease';
			case 'unit_milliseconds': return 'ms';
			case 'unit_pixels': return 'px';
			case 'dictionary_settings': return 'Dictionary Settings';
			case 'auto_search': return 'Auto search';
			case 'auto_search_debounce_delay': return 'Auto search debounce delay';
			case 'dictionary_font_size': return 'Dictionary font size';
			case 'close_on_export': return 'Close on Export';
			case 'close_on_export_on': return 'The Card Creator will now automatically close upon card export.';
			case 'close_on_export_off': return 'The Card Creator will no longer close upon card export.';
			case 'export_profile_empty': return 'Your export profile has no set fields and requires configuration.';
			case 'error_export_media_ankidroid': return 'There was an error in exporting media to AnkiDroid.';
			case 'error_add_note': return 'There was an error in adding a note to AnkiDroid.';
			case 'first_time_setup': return 'First-Time Setup';
			case 'first_time_setup_description': return 'Welcome to jidoujisho! Set your target language and a default profile will be tailored for you. You can change this later at anytime.';
			case 'maximum_entries': return 'Maximum dictionary entry query limit';
			case 'maximum_terms': return 'Maximum dictionary headwords in result';
			case 'use_br_tags': return 'Use line break tag instead of newline on export';
			case 'prepend_dictionary_names': return 'Prepend dictionary name in meaning';
			case 'highlight_on_tap': return 'Highlight text on tap';
			case 'no_audio_file': return 'No audio file to save.';
			case 'storage_permissions': return 'Please grant the following permissions for exporting to AnkiDroid.';
			case 'stream': return 'Stream';
			case 'network_subtitles_warning': return 'Embedded subtitles are unsupported for network streams.';
			case 'accessibility': return 'Permission is required to capture text from accessibility events.';
			case 'comments': return 'Comments';
			case 'replies': return 'Replies';
			case 'no_comments_queried': return 'No comments queried';
			case 'no_text_in_clipboard': return 'No text to display';
			case 'file_downloaded': return ({required Object name}) => 'File downloaded: ${name}';
			case 'cfhange_sort_order': return 'Change Sort Order';
			case 'login': return 'Login';
			case 'send': return 'Send';
			case 'no_messages': return 'Start a chat';
			case 'enter_message': return 'Enter message...';
			case 'clear_message_title': return 'Clear Messages';
			case 'clear_message_description': return 'This will clear all messages and start a new chat. Are you sure?';
			case 'error_chatgpt_response': return 'Request failed or rate-limited. Try again shortly or check your usage limits.';
			case 'pick_file': return 'Pick File';
			case 'open_url': return 'Open URL';
			case 'catalogs': return 'Catalogs';
			case 'name': return 'Name';
			case 'url': return 'URL';
			case 'duplicate_catalog': return 'A catalog with this URL already exists.';
			case 'no_catalogs_listed': return 'No catalogs listed';
			case 'go_back': return 'Go Back';
			case 'invalid_mokuro_file': return 'File is not a Mokuro generated HTML file.';
			case 'create_catalog': return 'Create Catalog';
			case 'adapt_ttu_theme': return 'Adapt dictionary popup to theme';
			case 'sentence_picker': return 'Sentence Picker';
			case 'field_locked': return ({required Object field}) => '${field} locked and will not clear on export while Creator is active.';
			case 'field_unlocked': return ({required Object field}) => '${field} unlocked and will clear on export.';
			case 'field_lock': return 'Lock Field';
			case 'field_unlock': return 'Unlock Field';
			case 'use_dark_theme': return 'Use dark theme';
			case 'stretch_to_fill_screen': return 'Stretch to Fill Screen';
			case 'processing_embedded_subtitles': return 'Embedded subtitles are processing. Try again later.';
			case 'transcript_playback_mode': return 'Transcript Playback Mode';
			case 'toggle_transcript_background': return 'Toggle Transcript Background';
			case 'seek': return 'Seek';
			case 'saved_tags': return 'Tags saved.';
			case 'structured_content_first': return ({required Object i}) => '${i} definitions are unsupported and were omitted.';
			case 'structured_content_second': return 'Consider a non-structured content version of this dictionary.';
			case 'missing_api_key': return 'API key not provided';
			case 'chatgpt_error': return 'There was an error in getting a response from ChatGPT.';
			case 'api_key': return 'API Key';
			case 'subtitle_delay_set': return ({required Object ms}) => 'Subtitle delay set to ${ms} ms.';
			case 'cancel': return 'Cancel';
			case 'server_port_in_use': return 'Local server port already in use';
			case 'google_fonts': return 'Google Fonts';
			case 'video_show': return 'Show video';
			case 'video_hide': return 'Hide video';
			case 'subtitle_timing_show': return 'Show subtitle timings';
			case 'subtitle_timing_hide': return 'Hide subtitle timings';
			case 'find_next': return 'Find Next';
			case 'find_previous': return 'Find Previous';
			case 'shadowing_mode': return 'Shadowing Mode';
			case 'display_settings': return 'Display Settings';
			case 'cloze': return 'Cloze';
			case 'info_standard_update': return 'New standard profile card type';
			case 'info_standard_update_content': return 'The standard profile now uses the『jidoujisho Kinomoto』 card type.\n\nYour legacy standard profile remains available for backwards compatibility.';
			case 'retrying_in.seconds': return ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
				one: 'Retrying in ${n} second...',
				other: 'Retrying in ${n} seconds...',
			);
			case 'view_replies.reply': return ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
				one: 'SHOW ${n} REPLY',
				other: 'SHOW ${n} REPLIES',
			);
			case 'manage_duplicate_checks': return 'Manage Duplicate Checks';
			case 'playback_normal': return 'Normal Playback Mode';
			case 'playback_condensed': return 'Condensed Playback Mode';
			case 'playback_auto_pause': return 'Subtitle Pause Playback Mode';
			case 'player_hardware_acceleration': return 'Hardware acceleration';
			case 'player_use_opensles': return 'OpenSL ES audio';
			case 'go_forward': return 'Go Forward';
			case 'browse': return 'Browse';
			case 'bookmark': return 'Bookmark';
			case 'add_bookmark': return 'Add Bookmark';
			case 'add_to_reading_list': return 'Add To Reading List';
			case 'reading_list_empty': return 'Reading list is empty';
			case 'reading_list_add_toast': return 'Added to reading list.';
			case 'reading_list_remove_toast': return 'Removed from the reading list.';
			case 'ad_block_hosts': return 'Ad-block hosts';
			case 'error_parsing_hosts_file': return 'Error parsing hosts file.';
			case 'double_tap_seek_duration': return 'Double tap seek duration';
			case 'player_background_play': return 'Background play';
			case 'loaded_from_cache': return 'Loaded from web archive cache.';
			case 'player_show_subtitle_in_notification': return 'Show subtitles in media notification';
			case 'subtitles_processing': return 'Subtitles are processing...';
			case 'video_unavailable': return 'Video Unavailable';
			case 'video_unavailable_content': return 'Cannot fetch streams. There may be restrictions in place that prevent watching this video.';
			case 'video_file_error': return 'Cannot Load File';
			case 'video_file_error_content': return 'Unable to load the video file. Please ensure this file exists and is located in a directory accessible by the application.';
			case 'ttu_add': return 'Add';
			case 'ttu_add_book': return 'Add a book';
			case 'ttu_reader_settings': return 'Reader settings';
			case 'ttu_reader_source': return 'Reader source';
			case 'ttu_empty_title': return 'Your library is empty';
			case 'ttu_empty_body': return 'Add an EPUB or HTMLZ file to start reading. Tap any word to look it up as you go.';
			case 'ttu_restore_backup': return 'Restore from a backup';
			case 'ttu_adding_book': return ({required Object name}) => 'Adding ${name}';
			case 'ttu_adding_books': return ({required Object n}) => 'Adding ${n} books';
			case 'ttu_reading_file': return 'ッツ is reading the file';
			case 'ttu_added_book': return ({required Object name}) => 'Added ${name}';
			case 'ttu_added_books': return ({required Object n}) => 'Added ${n} books';
			case 'ttu_import_failed': return ({required Object reason}) => 'Couldn\'t add the book: ${reason}';
			case 'ttu_unsupported_file': return ({required Object name}) => '${name} isn\'t an EPUB or HTMLZ file';
			case 'ttu_shelf_error': return 'Couldn\'t read the library.';
			case 'ttu_try_again': return 'Try again';
			case 'ttu_book_deleted': return ({required Object name}) => 'Deleted ${name}';
			case 'ttu_undo': return 'Undo';
			case 'ttu_read': return 'Read';
			case 'ttu_continue': return 'Continue';
			case 'ttu_memo': return 'Memo';
			case 'ttu_memos': return 'Memos';
			case 'ttu_new_memo': return 'New memo';
			case 'ttu_edit_memo': return 'Edit memo';
			case 'ttu_memo_placeholder': return 'A word to look up, a question, why this line matters';
			case 'ttu_memo_saved': return ({required Object position}) => 'Memo saved at ${position}';
			case 'ttu_memo_deleted': return 'Memo deleted';
			case 'ttu_no_memos': return 'No memos yet. Select text in the book and tap Memo to add one.';
			case 'ttu_no_memos_short': return 'No memos';
			case 'ttu_memo_hint': return 'Add more while reading: select text, then tap Memo.';
			case 'ttu_continue_reading': return 'Continue reading';
			case 'ttu_back_to_where': return 'Back to where you were';
			case 'ttu_before_jump': return 'before your last jump';
			case 'ttu_sort_position': return 'Position';
			case 'ttu_sort_newest': return 'Newest';
			case 'ttu_read_percent': return ({required Object percent}) => '${percent} read';
			case 'ttu_edit': return 'Edit';
			case 'ttu_delete': return 'Delete';
			case 'ttu_progress': return 'Progress';
			case 'ttu_read_label': return 'Read';
			case 'ttu_of_total': return ({required Object total}) => 'of ${total}';
			case 'ttu_last_opened': return 'Last opened';
			case 'ttu_not_opened': return 'Not yet';
			case 'ttu_added_when': return ({required Object when}) => 'Added ${when}';
			case 'ttu_language': return 'Language';
			case 'ttu_uses_dictionaries': return 'Looks words up in this language';
			case 'ttu_page': return 'Page';
			case 'ttu_page_note': return 'ッツ applies these when a book opens';
			case 'ttu_books_in': return ({required Object language}) => '${language} books';
			case 'ttu_theme': return 'Theme';
			case 'ttu_text_size': return 'Text size';
			case 'ttu_direction': return 'Direction';
			case 'ttu_vertical': return 'Vertical';
			case 'ttu_horizontal': return 'Horizontal';
			case 'ttu_layout': return 'Layout';
			case 'ttu_pages': return 'Pages';
			case 'ttu_scroll': return 'Scroll';
			case 'ttu_furigana': return 'Show furigana';
			case 'ttu_furigana_desc': return 'Readings above kanji, when the book has them';
			case 'ttu_while_reading': return 'While reading';
			case 'ttu_auto_save': return 'Save my place';
			case 'ttu_auto_save_desc': return 'Saves as you read and when you leave a book';
			case 'ttu_highlight': return 'Highlight the looked-up word';
			case 'ttu_highlight_desc': return 'Marks the word the dictionary looked up';
			case 'ttu_volume': return 'Volume keys turn pages';
			case 'ttu_volume_desc': return 'Each press turns one page';
			case 'ttu_volume_swap': return 'Swap volume keys';
			case 'ttu_volume_swap_desc': return 'If the keys go the wrong way';
			case 'ttu_scroll_step': return 'Scroll step';
			case 'ttu_scroll_step_desc': return 'How far each key press scrolls in Scroll layout';
			case 'ttu_full_screen': return 'Full screen';
			case 'ttu_full_screen_desc': return 'Draws under the status bar. Best on phones without a notch';
			case 'ttu_match_popup': return 'Popup matches the page';
			case 'ttu_match_popup_desc': return 'Uses the page theme for the popup';
			case 'ttu_more': return 'More';
			case 'ttu_backup_sync': return 'Backup and sync';
			case 'ttu_backup_sync_desc': return 'Google Drive, OneDrive or a folder. Opens ッツ';
			case 'ttu_all_settings': return 'All ッツ settings';
			case 'ttu_all_settings_desc': return 'Fonts, margins, page columns and more. Opens ッツ';
			case 'ttu_opening': return 'Opening';
			case 'ttu_jumping_to': return 'Jumping to';
			case 'ttu_returning_to': return 'Back to';
			case 'ttu_back_to': return ({required Object position}) => 'Back to ${position}';
			case 'ttu_saved_place': return ({required Object position}) => 'Saved your place at ${position}';
			case 'ttu_just_now': return 'Just now';
			case 'ttu_minutes_ago': return ({required Object n}) => '${n} min ago';
			case 'ttu_today': return 'Today';
			case 'ttu_yesterday': return 'Yesterday';
			case 'ttu_days_ago': return ({required Object n}) => '${n} days ago';
			case 'ttu_week_ago': return '1 week ago';
			case 'ttu_weeks_ago': return ({required Object n}) => '${n} weeks ago';
			case 'ttu_month_ago': return '1 month ago';
			case 'ttu_months_ago': return ({required Object n}) => '${n} months ago';
			case 'my_words': return 'My terms';
			case 'my_words_add': return 'Add to My terms';
			case 'my_words_edit': return 'Edit term';
			case 'my_words_word': return 'Term';
			case 'my_words_reading': return 'Reading';
			case 'my_words_meaning': return 'Meaning (optional)';
			case 'my_words_meaning_hint': return 'Retrieval-augmented generation';
			case 'my_words_saved': return 'Saved to My terms';
			case 'my_words_deleted': return 'Term removed';
			case 'my_words_empty': return 'No terms yet';
			case 'my_words_info': return 'Your own meanings. They show first whenever you look the term up, in any book. Select text like "software as a service (SaaS)" and tap Add term to save SaaS in one tap.';
			case 'my_words_new': return 'New term';
			case 'add_word': return 'Add term';
			case 'ttu_page_info': return 'Books in this language open with these settings.';
			case 'ttu_font': return 'Font';
			case 'ttu_font_serif': return 'Serif';
			case 'ttu_font_sans': return 'Sans';
			case 'ttu_font_mincho': return 'Mincho';
			case 'ttu_font_klee': return 'Klee';
			case 'ttu_line_spacing': return 'Line spacing';
			case 'ttu_margins': return 'Margins';
			case 'ttu_columns': return 'Columns';
			case 'ttu_columns_auto': return 'Auto';
			case 'ttu_furigana_label': return 'Furigana';
			case 'ttu_furigana_show': return 'Show';
			case 'ttu_furigana_faded': return 'Faded';
			case 'ttu_furigana_hidden': return 'Hide';
			case 'ttu_furigana_tap': return 'On tap';
			case 'ttu_furigana_info': return 'Faded shows readings in grey. On tap shows them when you tap a word.';
			case 'ttu_avoid_break': return 'Keep paragraphs whole';
			case 'ttu_avoid_break_info': return 'Moves a paragraph to the next page instead of splitting it.';
			case 'ttu_blur_images': return 'Blur images';
			case 'ttu_blur_images_info': return 'Hides pictures behind a spoiler cover until you tap them.';
			case 'ttu_full_screen_info': return 'Hides the status and navigation bars. A swipe from the edge then only shows them, so it takes two swipes to leave or open notifications.';
			case 'ttu_camera_area': return 'Use the camera area';
			case 'ttu_camera_area_info': return 'Lets the page run under the camera cutout.';
			case 'ttu_keep_screen_on': return 'Keep the screen on';
			case 'ttu_auto_save_info': return 'Saves as you read and when you leave a book.';
			case 'ttu_match_popup_info': return 'Uses the page theme for the dictionary popup.';
			case 'ttu_scroll_step_info': return 'How far each key press scrolls in Scroll layout.';
			case 'file_access_title': return 'Allow access to your files?';
			case 'file_access_media': return 'Photos, videos and audio';
			case 'file_access_all': return 'All files';
			case 'file_access_allow': return 'Allow';
			case 'file_access_not_now': return 'Not now';
			case 'file_access_info': return 'Needed to open videos and manga from folders on your phone. Photos, videos and audio is enough to play videos; All files also finds subtitle files next to them. Books and dictionaries never need this.';
			case 'file_access_info_short': return 'Needed to open videos and manga from folders on your phone. Books and dictionaries never need this.';
			case 'file_access_denied': return 'Files can\'t be opened without access. You can allow it in Android settings.';
			case 'ttu_language_changed': return ({required Object language}) => 'Words in this book are now looked up in ${language}';
			case 'my_terms_from': return ({required Object title}) => 'From ${title}';
			case 'my_terms_saved_term': return ({required Object term}) => 'Saved ${term}';
			case 'my_terms_edit': return 'Edit';
			case 'ttu_terms': return 'Terms';
			case 'ttu_no_terms': return 'No terms saved from this book yet';
			case 'ttu_place_kept': return ({required Object position}) => 'Your place stays at ${position}';
			case 'ttu_read_on': return 'Read';
			case 'ttu_font_genei': return 'Genei';
			case 'ttu_chapters': return 'Chapters';
			case 'ttu_no_chapters': return 'This book has no chapter list';
			case 'ttu_applying': return 'Applying settings';
			case 'ttu_memos_on_page': return 'Show memos on the page';
			case 'ttu_memos_on_page_info': return 'A short note above each memo\'s passage. Tap it to read the whole memo.';
			case 'ttu_color_amber': return 'Amber';
			case 'ttu_color_rose': return 'Pink';
			case 'ttu_color_green': return 'Green';
			case 'ttu_color_sky': return 'Blue';
			case 'ttu_color_violet': return 'Purple';
			case 'catalog_title': return 'Online dictionaries';
			case 'catalog_open': return 'Online';
			case 'catalog_connect_title': return 'Connect a dictionary server';
			case 'catalog_connect_hint': return 'Paste the server\'s address and a token. A read token can browse and download; an admin token can also upload and delete. Pasting a link with the token after # fills in both.';
			case 'catalog_address': return 'Server address';
			case 'catalog_token': return 'Token';
			case 'catalog_connect': return 'Connect';
			case 'catalog_all': return 'All';
			case 'catalog_section_bilingual': return 'Bilingual';
			case 'catalog_section_monolingual': return 'Monolingual';
			case 'catalog_section_kanji': return 'Kanji';
			case 'catalog_section_frequency': return 'Frequency';
			case 'catalog_section_pronunciation': return 'Pronunciation';
			case 'catalog_section_other': return 'Other';
			case 'catalog_entries': return ({required Object n}) => '${n} entries';
			case 'catalog_installed': return 'Installed';
			case 'catalog_preparing': return 'Preparing';
			case 'catalog_failed': return 'Couldn\'t prepare';
			case 'catalog_download': return 'Download';
			case 'catalog_search_hint': return 'Search this dictionary';
			case 'catalog_nothing_found': return ({required Object query}) => 'Nothing found for ${query}';
			case 'catalog_upload': return 'Upload';
			case 'catalog_uploading': return ({required Object name}) => 'Uploading ${name}';
			case 'catalog_uploaded': return ({required Object name}) => '${name} is on the server and being prepared';
			case 'catalog_replace': return 'Replace';
			case 'catalog_delete': return 'Delete from server';
			case 'catalog_delete_confirm': return 'Tap again to delete';
			case 'catalog_deleted': return ({required Object name}) => '${name} deleted from the server';
			case 'catalog_words': return 'Words';
			case 'catalog_definitions': return 'Definitions';
			case 'catalog_languages_hint': return 'The language you look words up in, and the language of the definitions. Dictionaries without this in their index are labelled by the server from their text; correct it here if it guessed wrong.';
			case 'catalog_save': return 'Save';
			case 'catalog_server': return 'Server';
			case 'catalog_disconnect': return 'Disconnect';
			case 'catalog_role_admin': return 'Admin';
			case 'catalog_role_read': return 'Read only';
			case 'catalog_empty': return 'No dictionaries on the server yet';
			case 'catalog_imported': return ({required Object name}) => '${name} imported';
			case 'catalog_unknown_language': return 'Unknown';
			case 'backup_title': return 'Backup and restore';
			case 'backup_menu': return 'Backup and restore';
			case 'backup_step_settings': return 'Settings';
			case 'backup_step_memos': return 'Memos and terms';
			case 'backup_step_books': return ({required Object language}) => 'Books (${language})';
			case 'backup_step_dictionary': return ({required Object name}) => 'Dictionary: ${name}';
			case 'backup_step_packing': return 'Packing';
			case 'backup_step_download': return ({required Object name}) => 'Downloading ${name}';
			case 'backup_step_install': return ({required Object name}) => 'Installing ${name}';
			case 'backup_not_a_backup': return 'This file isn\'t a jidoujisho backup.';
			case 'backup_too_new': return 'This backup was made by a newer version of the app. Update the app to restore it.';
			case 'backup_make': return 'Back up';
			case 'backup_make_hint': return 'One file with your books and reading positions, ッツ\'s settings and fonts, memos, My terms, history, Anki profiles, app settings with your dictionary server link, and your dictionaries. Dictionaries that are on your dictionary server are downloaded again on restore; the others travel in the file. The file includes your server token, so keep it private.';
			case 'backup_restore': return 'Restore';
			case 'backup_restore_hint': return 'Replaces this device\'s books, memos, terms and settings with the backup\'s. Dictionaries already on this device are kept; the backup\'s others are installed.';
			case 'backup_choose': return 'Choose a backup';
			case 'backup_saved': return 'Backup saved';
			case 'backup_not_saved': return 'The backup wasn\'t saved';
			case 'backup_books': return 'Books';
			case 'backup_dictionaries': return 'Dictionaries';
			case 'backup_dictionaries_split': return ({required Object included, required Object online}) => '${included} in the file · ${online} from your server';
			case 'backup_memos': return 'Memos';
			case 'backup_terms': return 'My terms';
			case 'backup_made': return ({required Object date, required Object version}) => 'Made ${date} with ${version}';
			case 'backup_restore_confirm': return 'Tap again to replace this device\'s data';
			case 'backup_restored': return 'Restored. Restart the app to finish.';
			case 'backup_restart': return 'Close the app';
			case 'backup_failed_dictionaries': return ({required Object names}) => 'Couldn\'t install: ${names}';
			case 'backup_working': return 'Keep the app open until this finishes.';
			case 'theme_menu': return 'Theme';
			case 'theme_mode': return 'Mode';
			case 'theme_mode_system': return 'System';
			case 'theme_mode_light': return 'Light';
			case 'theme_mode_dark': return 'Dark';
			case 'theme_mode_hint': return 'System follows your phone and switches with it.';
			case 'theme_accent': return 'Accent';
			case 'theme_accent_red': return 'Red';
			case 'theme_accent_rose': return 'Pink';
			case 'theme_accent_orange': return 'Orange';
			case 'theme_accent_green': return 'Green';
			case 'theme_accent_teal': return 'Teal';
			case 'theme_accent_blue': return 'Blue';
			case 'theme_accent_violet': return 'Purple';
			case 'theme_accent_slate': return 'Slate';
			case 'ttu_search': return 'Search';
			case 'ttu_search_hint': return 'Search this book';
			case 'ttu_search_found': return ({required Object count}) => '${count} found';
			case 'ttu_search_first': return ({required Object shown}) => 'The first ${shown} are listed';
			case 'ttu_search_none': return 'Not in this book';
			case 'ttu_search_reading': return 'Reading the book…';
			case 'ttu_search_stay': return 'Stay here';
			case 'ttu_search_list': return 'All results';
			case 'ttu_search_previous': return 'Previous result';
			case 'ttu_search_next': return 'Next result';
			case 'ttu_search_info': return 'Matches ignore the difference between hiragana and katakana, full- and half-width letters, and upper and lower case. Furigana is not searched. Your saved place stays where it was until you choose Stay here.';
			case 'ttu_favourite': return 'Favourite';
			case 'ttu_unfavourite': return 'Remove from favourites';
			case 'ttu_favourites': return 'Favourites';
			case 'ttu_shelf': return 'Shelf';
			case 'ttu_group_by': return 'Group by';
			case 'ttu_group_by_none': return 'None';
			case 'ttu_group_by_groups': return 'My groups';
			case 'ttu_group_by_language': return 'Language';
			case 'ttu_group_by_progress': return 'Progress';
			case 'ttu_group': return 'Group';
			case 'ttu_group_none': return 'None';
			case 'ttu_ungrouped': return 'Not in a group';
			case 'ttu_progress_reading': return 'Reading';
			case 'ttu_progress_unread': return 'Not started';
			case 'ttu_progress_finished': return 'Finished';
			case 'ttu_other_books': return 'Books';
			case 'ttu_new_group': return 'New group';
			case 'ttu_group_name': return 'Group name';
			case 'ttu_rename_group': return 'Rename';
			case 'ttu_delete_group': return 'Delete group';
			case 'ttu_group_info': return 'Books show under their group when the shelf is grouped by My groups, in the shelf settings.';
			case 'ttu_group_by_info': return 'Favourites always come first. Tap a heading to fold it away.';
			case 'ttu_this_book': return 'This book';
			case 'ttu_follow_links': return 'Follow links';
			case 'ttu_follow_links_info': return 'On, tapping a link takes you where it points, with a way back. Off, links read as plain text and tapping one looks the word up.';
			case 'ttu_book_fonts': return 'Book\'s own fonts';
			case 'ttu_book_fonts_info': return 'Off, your font is used all through the book. Code keeps its fixed-width font.';
			case 'ttu_repaired_partly': return ({required Object title}) => 'Parts of ${title} were missing from the file. The rest was added.';
			case 'catalog_description': return 'Description';
			case 'catalog_description_hint': return 'What it\'s good for, or who it\'s for';
			case 'catalog_description_shown_in': return ({required Object language}) => 'Shows only when the app is in ${language}';
			case 'import_replacing': return ({required Object name}) => 'Replacing the older ${name}…';
			case 'catalog_update': return 'Update to this revision';
			case 'dictionary_about': return 'About';
			case 'dictionary_by': return ({required Object author}) => 'By ${author}';
			case 'dictionary_delete_all': return 'Delete all dictionaries';
			case 'dictionary_import': return 'Import';
			case 'dictionary_collapsed': return 'Starts collapsed';
			case 'dictionary_show_in_results': return 'Show in results';
			case 'dictionary_start_collapsed': return 'Start collapsed in results';
			case 'dictionary_from_server': return 'Downloaded';
			case 'dictionary_from_file': return 'Imported from a file';
			case 'dictionary_delete': return 'Delete dictionary';
			case 'ttu_add_font': return 'Add font';
			case 'ttu_font_unsupported': return 'Fonts can be .ttf, .otf, .woff or .woff2 files.';
			case 'ttu_font_failed': return 'The font could not be added.';
			case 'ttu_remove_font': return ({required Object name}) => 'Remove ${name}';
			case 'auto_backup_title': return 'Keep a backup up to date';
			case 'auto_backup_hint': return 'One backup file, in a place you choose such as Google Drive, written over when it is due, so only the newest is kept. It updates while the app is open, a little after you open it.';
			case 'auto_backup_choose': return 'Choose where to keep it';
			case 'auto_backup_file': return 'Backup file';
			case 'auto_backup_daily': return 'Every day';
			case 'auto_backup_weekly': return 'Every week';
			case 'auto_backup_own_dictionaries': return 'Include dictionaries I added myself';
			case 'auto_backup_own_dictionaries_info': return 'They can make the file large. Dictionaries from your server are always listed and download again when restoring.';
			case 'auto_backup_now': return 'Update now';
			case 'auto_backup_off': return 'Turn off';
			case 'auto_backup_updated': return ({required Object date}) => 'Updated ${date}';
			case 'auto_backup_never': return 'Not updated yet';
			case 'auto_backup_failed': return ({required Object reason}) => 'Last update failed: ${reason}';
			case 'auto_backup_lost': return 'The backup file can no longer be reached. Choose where to keep it again.';
			case 'auto_backup_writing': return 'Writing the backup file';
			case 'auto_backup_cannot_keep': return 'That place can\'t be written to again later. Choose another, such as a folder or Google Drive.';
			case 'auto_backup_running': return 'Updating the backup file';
			case 'ttu_tags': return 'Tags';
			case 'ttu_add_tag': return 'Add a tag';
			case 'ttu_tags_none': return 'No tags yet';
			case 'ttu_tags_used_before': return 'Used before';
			case 'ttu_tags_info': return 'Tags show on the book\'s cover. Pick one you used before or type a new one.';
			case 'ttu_theme_names.light': return 'Light';
			case 'ttu_theme_names.ecru': return 'Ecru';
			case 'ttu_theme_names.water': return 'Water';
			case 'ttu_theme_names.gray': return 'Gray';
			case 'ttu_theme_names.dark': return 'Dark';
			case 'ttu_theme_names.black': return 'Black';
			case 'language_names.ja': return 'Japanese';
			case 'language_names.en': return 'English';
			case 'language_names.vi': return 'Vietnamese';
			case 'language_names.zh': return 'Chinese';
			case 'language_names.ko': return 'Korean';
			case 'language_names.fr': return 'French';
			case 'language_names.de': return 'German';
			case 'language_names.es': return 'Spanish';
			case 'language_names.ru': return 'Russian';
			case 'language_names.th': return 'Thai';
			case 'language_names.ar': return 'Arabic';
			case 'addons.field.sentence.label': return 'Sentence';
			case 'addons.field.sentence.description': return 'Subtitles, book excerpts and other contextual information.';
			case 'addons.field.term.label': return 'Term';
			case 'addons.field.term.description': return 'Dictionary headword or phrase.';
			case 'addons.field.reading.label': return 'Reading';
			case 'addons.field.reading.description': return 'Pronunciation or speech pattern.';
			case 'addons.field.meaning.label': return 'Meaning';
			case 'addons.field.meaning.description': return 'All dictionary definitions of a term.';
			case 'addons.field.notes.label': return 'Notes';
			case 'addons.field.notes.description': return 'Supplementary information or personal observations.';
			case 'addons.field.image.label': return 'Image';
			case 'addons.field.image.description': return 'Visual supplement. Text field can be used to enter search terms for image sources.';
			case 'addons.field.audio.label': return 'Term Audio';
			case 'addons.field.audio.description': return 'Audio pertaining to the term. Text field can be used to enter search terms for audio sources.';
			case 'addons.field.audio_sentence.label': return 'Sentence Audio';
			case 'addons.field.audio_sentence.description': return 'Audio pertaining to the sentence. Text field can be used to enter search terms for audio sources.';
			case 'addons.field.pitch_accent.label': return 'Pitch Accent';
			case 'addons.field.pitch_accent.description': return 'Pre-fills text to export for pitch accent diagrams.';
			case 'addons.field.furigana.label': return 'Furigana';
			case 'addons.field.furigana.description': return 'Pre-fills text to export for Furigana.';
			case 'addons.field.frequency.label': return 'Frequency';
			case 'addons.field.frequency.description': return 'Adds frequency of headword for sorting purposes, calculated using the harmonic mean.';
			case 'addons.field.context.label': return 'Context';
			case 'addons.field.context.description': return 'Name of current source media.';
			case 'addons.field.cloze_before.label': return 'Cloze Before';
			case 'addons.field.cloze_before.description': return 'Text before highlighted text in a sentence. Empty if nothing is highlighted.';
			case 'addons.field.cloze_inside.label': return 'Cloze Inside';
			case 'addons.field.cloze_inside.description': return 'Highlighted text in a sentence.';
			case 'addons.field.cloze_after.label': return 'Cloze After';
			case 'addons.field.cloze_after.description': return 'Text after highlighted text in a sentence. Empty if nothing is highlighted.';
			case 'addons.field.expanded_meaning.label': return 'Expanded Meaning';
			case 'addons.field.expanded_meaning.description': return 'Dictionary definitions only from expanded dictionaries.';
			case 'addons.field.collapsed_meaning.label': return 'Collapsed Meaning';
			case 'addons.field.collapsed_meaning.description': return 'Dictionary definitions only from collapsed dictionaries.';
			case 'addons.field.hidden_meaning.label': return 'Hidden Meaning';
			case 'addons.field.hidden_meaning.description': return 'Dictionary definitions only from hidden dictionaries.';
			case 'addons.field.tags.label': return 'Tags';
			case 'addons.field.tags.description': return 'Organise notes in a deck with space-delimited labels.';
			case 'addons.enhancement.clear_field.label': return 'Clear Field';
			case 'addons.enhancement.clear_field.description': return 'Quickly empty the content of a field.';
			case 'addons.enhancement.jpd101_audio.label': return 'JapanesePod101 Audio';
			case 'addons.enhancement.jpd101_audio.description': return 'Search for matching word pronunciations from JapanesePod101.';
			case 'addons.enhancement.forvo_audio.label': return 'Forvo Audio';
			case 'addons.enhancement.forvo_audio.description': return 'Get word audio from Forvo.';
			case 'addons.enhancement.pick_audio.label': return 'Pick Audio';
			case 'addons.enhancement.pick_audio.description': return 'Pick an audio file to use with an external picker.';
			case 'addons.enhancement.audio_recorder.label': return 'Audio Recorder';
			case 'addons.enhancement.audio_recorder.description': return 'Record and use audio captured from the device microphone.';
			case 'addons.enhancement.open_stash.label': return 'Open Stash';
			case 'addons.enhancement.open_stash.description': return 'View and manage previously stashed text.';
			case 'addons.enhancement.pop_from_stash.label': return 'Pop From Stash';
			case 'addons.enhancement.pop_from_stash.description': return 'Quickly pop the latest item in the Stash.';
			case 'addons.enhancement.text_segmentation.label': return 'Text Segmentation';
			case 'addons.enhancement.text_segmentation.description': return 'Search or select a new term from segmented text.';
			case 'addons.enhancement.bing_images_search.label': return 'Bing Images Search';
			case 'addons.enhancement.bing_images_search.description': return 'Search Bing for images with the current image query or the word.';
			case 'addons.enhancement.crop_image.label': return 'Crop Image';
			case 'addons.enhancement.crop_image.description': return 'Crop the current selected image.';
			case 'addons.enhancement.pick_image.label': return 'Pick Image';
			case 'addons.enhancement.pick_image.description': return 'Pick a new image to use with an external picker.';
			case 'addons.enhancement.camera.label': return 'Camera';
			case 'addons.enhancement.camera.description': return 'Take a new photo to use as the new image.';
			case 'addons.enhancement.sentence_picker.label': return 'Sentence Picker';
			case 'addons.enhancement.sentence_picker.description': return 'Pick sentences delimited by punctuation and spacing.';
			case 'addons.enhancement.search_dictionary.label': return 'Search Dictionary';
			case 'addons.enhancement.search_dictionary.description': return 'Search the dictionary with the content of a field.';
			case 'addons.enhancement.massif_example_sentences.label': return 'Massif Example Sentences';
			case 'addons.enhancement.massif_example_sentences.description': return 'Get curated example sentences via Massif.';
			case 'addons.enhancement.tatoeba_example_sentences.label': return 'Tatoeba Example Sentences';
			case 'addons.enhancement.tatoeba_example_sentences.description': return 'Pick example phrases and sentences from Tatoeba.';
			case 'addons.enhancement.immersion_kit.label': return 'ImmersionKit';
			case 'addons.enhancement.immersion_kit.description': return 'Get example sentences complete with an image and audio.';
			case 'addons.enhancement.save_tags.label': return 'Save Tags';
			case 'addons.enhancement.save_tags.description': return 'Persist the current text in the Tags field.';
			case 'addons.action.card_creator.label': return 'Card Creator';
			case 'addons.action.card_creator.description': return 'Create a card with the selected dictionary entry parameters and edit before export.';
			case 'addons.action.instant_export.label': return 'Instant Export';
			case 'addons.action.instant_export.description': return 'Export a card with the selected dictionary entry parameters.';
			case 'addons.action.add_to_stash.label': return 'Add To Stash';
			case 'addons.action.add_to_stash.description': return 'Quickly save the headword of a dictionary entry to the Stash.';
			case 'addons.action.my_words.label': return 'My Terms';
			case 'addons.action.my_words.description': return 'Write your own meaning for a term. It shows first whenever you look the term up.';
			case 'addons.action.copy_to_clipboard.label': return 'Copy To Clipboard';
			case 'addons.action.copy_to_clipboard.description': return 'Copy the headword of a dictionary entry to the clipboard.';
			case 'addons.action.share.label': return 'Share';
			case 'addons.action.share.description': return 'Share the details of a dictionary term.';
			case 'addons.action.play_audio.label': return 'Play Audio';
			case 'addons.action.play_audio.description': return 'Attempts to play audio based on the Audio enhancements. The auto is the top priority.';
			case 'addons.source.player_local_media.label': return 'Local Media';
			case 'addons.source.player_local_media.description': return 'Play videos sourced from local device storage.';
			case 'addons.source.player_youtube.label': return 'YouTube';
			case 'addons.source.player_youtube.description': return 'Search and watch videos from YouTube.';
			case 'addons.source.player_network_stream.label': return 'Network Stream';
			case 'addons.source.player_network_stream.description': return 'Stream videos from a direct URL.';
			case 'addons.source.reader_ttu.label': return 'ッツ Ebook Reader';
			case 'addons.source.reader_ttu.description': return 'Read EPUBs and mine sentences via an embedded web reader.';
			case 'addons.source.reader_mokuro.label': return 'Mokuro';
			case 'addons.source.reader_mokuro.description': return 'Read manga volumes pre-processed as a single HTML file via Mokuro.';
			case 'addons.source.reader_browser.label': return 'Browser';
			case 'addons.source.reader_browser.description': return 'Navigate websites with a browser which allows searching and mining selected text.';
			case 'addons.source.reader_lyrics.label': return 'Lyrics';
			case 'addons.source.reader_lyrics.description': return 'Allows fetching and highlighting lyrics of current played media fetched from Google and Uta-Net.';
			case 'addons.source.reader_chatgpt.label': return 'ChatGPT';
			case 'addons.source.reader_chatgpt.description': return 'Allows the user to interact with an AI language model with an official API key from OpenAI.';
			case 'addons.source.reader_clipboard.label': return 'Clipboard';
			case 'addons.source.reader_clipboard.description': return 'Allows text pasted from the clipboard to be displayed as selectable text.';
			case 'addons.source.reader_websocket.label': return 'WebSocket';
			case 'addons.source.reader_websocket.description': return 'Select and mine text received from a WebSocket server.';
			case 'addons.source.viewer_camera.label': return 'Camera';
			case 'addons.source.viewer_camera.description': return 'View images taken with the camera or picked from media.';
			default: return null;
		}
	}
}

extension on _StringsVi {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'dictionary_media_type': return 'Từ điển';
			case 'player_media_type': return 'Trình phát';
			case 'reader_media_type': return 'Trình đọc';
			case 'viewer_media_type': return 'Trình xem';
			case 'back': return 'Quay lại';
			case 'search': return 'Tìm kiếm';
			case 'search_ellipsis': return 'Tìm kiếm...';
			case 'show_more': return 'Xem thêm';
			case 'show_menu': return 'Hiện menu';
			case 'stash': return 'Kho tạm';
			case 'pick_image': return 'Chọn ảnh';
			case 'undo': return 'Hoàn tác';
			case 'copy': return 'Sao chép';
			case 'clear': return 'Xóa';
			case 'creator': return 'Trình tạo';
			case 'share': return 'Chia sẻ';
			case 'resume_last_media': return 'Tiếp tục nội dung gần nhất';
			case 'change_source': return 'Đổi nguồn';
			case 'launch_source': return 'Mở nguồn';
			case 'card_creator': return 'Trình tạo thẻ';
			case 'target_language': return 'Ngôn ngữ đích';
			case 'show_options': return 'Hiện tùy chọn';
			case 'switch_profiles': return 'Đổi hồ sơ';
			case 'dictionaries': return 'Từ điển';
			case 'enhancements': return 'Tiện ích bổ trợ';
			case 'app_locale': return 'Ngôn ngữ ứng dụng';
			case 'app_locale_warning': return 'Các tiện ích cộng đồng và tiện ích bổ trợ được nhà phát triển tương ứng quản lý, nên có thể hiển thị bằng ngôn ngữ gốc.';
			case 'dialog_play': return 'PHÁT';
			case 'dialog_read': return 'ĐỌC';
			case 'dialog_view': return 'XEM';
			case 'dialog_edit': return 'SỬA';
			case 'dialog_export': return 'XUẤT';
			case 'dialog_import': return 'NHẬP';
			case 'dialog_close': return 'ĐÓNG';
			case 'dialog_clear': return 'XÓA';
			case 'dialog_create': return 'TẠO';
			case 'dialog_delete': return 'XÓA';
			case 'dialog_cancel': return 'HỦY';
			case 'dialog_select': return 'CHỌN';
			case 'dialog_stash': return 'KHO TẠM';
			case 'dialog_search': return 'TÌM KIẾM';
			case 'dialog_exit': return 'THOÁT';
			case 'dialog_share': return 'CHIA SẺ';
			case 'dialog_pop': return 'LẤY RA';
			case 'dialog_save': return 'LƯU';
			case 'dialog_set': return 'ĐẶT';
			case 'dialog_browse': return 'DUYỆT';
			case 'dialog_channel': return 'KÊNH';
			case 'dialog_directory': return 'THƯ MỤC';
			case 'dialog_crop': return 'CẮT';
			case 'dialog_connect': return 'KẾT NỐI';
			case 'dialog_append': return 'THÊM';
			case 'dialog_record': return 'GHI';
			case 'dialog_manage': return 'QUẢN LÝ';
			case 'dialog_stop': return 'DỪNG';
			case 'dialog_done': return 'XONG';
			case 'reset': return 'Đặt lại';
			case 'dialog_launch_ankidroid': return 'MỞ ANKIDROID';
			case 'media_item_delete_confirmation': return 'Mục này sẽ bị xóa khỏi lịch sử. Bạn có chắc muốn tiếp tục không?';
			case 'dictionaries_delete_confirmation': return 'Xóa một từ điển cũng sẽ xóa tất cả kết quả từ điển khỏi lịch sử. Bạn có chắc muốn tiếp tục không?';
			case 'mappings_delete_confirmation': return 'Hồ sơ này sẽ bị xóa. Bạn có chắc muốn tiếp tục không?';
			case 'catalog_delete_confirmation': return 'Danh mục này sẽ bị xóa. Bạn có chắc muốn tiếp tục không?';
			case 'dictionaries_deleting_data': return 'Đang xóa dữ liệu từ điển...';
			case 'dictionaries_menu_empty': return 'Nhập từ điển để sử dụng';
			case 'options_theme_light': return 'Dùng giao diện sáng';
			case 'options_theme_dark': return 'Dùng giao diện tối';
			case 'options_incognito_on': return 'Bật chế độ ẩn danh';
			case 'options_incognito_off': return 'Tắt chế độ ẩn danh';
			case 'options_dictionaries': return 'Quản lý từ điển';
			case 'options_profiles': return 'Hồ sơ xuất thẻ';
			case 'options_enhancements': return 'Tiện ích bổ trợ của người dùng';
			case 'options_language': return 'Cài đặt ngôn ngữ';
			case 'options_github': return 'Xem kho lưu trữ trên GitHub';
			case 'options_attribution': return 'Giấy phép và ghi công';
			case 'options_copy': return 'Sao chép';
			case 'options_collapse': return 'Thu gọn';
			case 'options_expand': return 'Mở rộng';
			case 'options_delete': return 'Xóa';
			case 'options_show': return 'Hiện';
			case 'options_hide': return 'Ẩn';
			case 'options_edit': return 'Sửa';
			case 'info_empty_home_tab': return 'Lịch sử trống';
			case 'delete_in_progress': return 'Đang xóa';
			case 'import_format': return 'Định dạng nhập';
			case 'import_in_progress': return 'Đang nhập';
			case 'import_start': return 'Đang chuẩn bị nhập...';
			case 'import_clean': return 'Đang dọn dẹp không gian làm việc...';
			case 'import_extract_count': return ({required Object n}) => 'Đã giải nén ${n} tệp...';
			case 'import_extract': return 'Đang giải nén tệp...';
			case 'import_name': return ({required Object name}) => 'Đang nhập 『${name}』...';
			case 'import_entries': return 'Đang xử lý các mục...';
			case 'import_found_entry': return ({required Object count}) => 'Đã tìm thấy ${count} mục...';
			case 'import_found_tag': return ({required Object count}) => 'Đã tìm thấy ${count} nhãn...';
			case 'import_found_frequency': return ({required Object count}) => 'Đã tìm thấy ${count} mục tần suất...';
			case 'import_found_pitch': return ({required Object count}) => 'Đã tìm thấy ${count} mục trọng âm...';
			case 'import_write_entry': return ({required Object count, required Object total}) => 'Đang ghi các mục:\n${count} / ${total}';
			case 'import_write_tag': return ({required Object count, required Object total}) => 'Đang ghi các nhãn:\n${count} / ${total}';
			case 'import_write_frequency': return ({required Object count, required Object total}) => 'Đang ghi các mục tần suất:\n${count} / ${total}';
			case 'import_write_pitch': return ({required Object count, required Object total}) => 'Đang ghi các mục trọng âm:\n${count} / ${total}';
			case 'import_failed': return 'Nhập từ điển không thành công.';
			case 'import_complete': return 'Đã nhập từ điển.';
			case 'import_duplicate': return ({required Object name}) => 'Từ điển có tên 『${name}』 đã được nhập.';
			case 'dialog_title_dictionary_clear': return 'Xóa tất cả từ điển?';
			case 'dialog_content_dictionary_clear': return 'Xóa cơ sở dữ liệu từ điển cũng sẽ xóa tất cả kết quả tìm kiếm trong lịch sử.';
			case 'dialog_title_dictionary_delete': return ({required Object name}) => 'Xóa 『${name}』?';
			case 'dialog_content_dictionary_delete': return 'Xóa một từ điển riêng lẻ có thể mất nhiều thời gian hơn xóa toàn bộ cơ sở dữ liệu từ điển. Thao tác này cũng sẽ xóa tất cả kết quả tìm kiếm trong lịch sử.';
			case 'delete_dictionary_data': return 'Đang xóa tất cả dữ liệu từ điển...';
			case 'dictionary_tag': return ({required Object name}) => 'Được nhập từ ${name}';
			case 'legalese': return 'Bộ công cụ học ngôn ngữ qua đắm chìm (immersion), đầy đủ tính năng, dành cho thiết bị di động.\n\nBan đầu được Arianne Orpilla xây dựng cho cộng đồng học tiếng Nhật. Logo do suzy và Aaron Marbella thiết kế.\n\njidoujisho là phần mềm miễn phí và mã nguồn mở. Xem kho lưu trữ của dự án để biết danh sách đầy đủ các giấy phép khác và thông báo ghi công. Bạn thích ứng dụng này? Hãy giúp chúng tôi bằng cách gửi phản hồi, quyên góp, báo cáo sự cố hoặc đóng góp cải tiến trên GitHub.';
			case 'same_name_dictionary_found': return 'Đã tìm thấy từ điển trùng tên.';
			case 'import_file_extension_invalid': return ({required Object extensions}) => 'Định dạng này yêu cầu tệp có một trong các phần mở rộng sau: ${extensions}';
			case 'field_label_empty': return 'Trống';
			case 'model_to_map': return 'Loại thẻ dùng cho hồ sơ mới';
			case 'mapping_name': return 'Tên hồ sơ';
			case 'mapping_name_hint': return 'Tên gán cho hồ sơ';
			case 'error_profile_name': return 'Tên hồ sơ không hợp lệ';
			case 'error_profile_name_content': return 'Hồ sơ có tên này đã tồn tại hoặc không hợp lệ nên không thể lưu.';
			case 'error_standard_profile_name': return 'Tên hồ sơ không hợp lệ';
			case 'error_standard_profile_name_content': return 'Không thể đổi tên hồ sơ tiêu chuẩn.';
			case 'error_ankidroid_api': return 'Lỗi AnkiDroid';
			case 'error_ankidroid_api_content': return 'Đã xảy ra sự cố khi giao tiếp với AnkiDroid.\n\nHãy đảm bảo dịch vụ nền của AnkiDroid đang hoạt động và mọi quyền cần thiết của ứng dụng đều đã được cấp để tiếp tục.';
			case 'info_standard_model': return 'Đã thêm loại thẻ tiêu chuẩn';
			case 'info_standard_model_content': return '『jidoujisho Kinomoto』 đã được thêm vào AnkiDroid dưới dạng loại thẻ mới.\n\nBạn có thể dùng thiết lập với loại thẻ hoặc thứ tự trường khác bằng cách thêm hồ sơ xuất mới.';
			case 'error_model_missing': return 'Thiếu loại thẻ';
			case 'error_model_missing_content': return 'Loại thẻ tương ứng với hồ sơ hiện được chọn không còn tồn tại.\n\nHồ sơ sẽ bị xóa và hồ sơ tiêu chuẩn đã được chọn thay thế.';
			case 'error_model_changed': return 'Loại thẻ đã thay đổi';
			case 'error_model_changed_content': return 'Số trường của loại thẻ tương ứng với hồ sơ đã chọn đã thay đổi.\n\nCác trường trong hồ sơ hiện được chọn đã được đặt lại và cần cấu hình lại.';
			case 'creator_exporting_as': return 'Đang tạo thẻ bằng hồ sơ';
			case 'creator_exporting_as_fields_editing': return 'Đang sửa các trường cho hồ sơ';
			case 'creator_exporting_as_enhancements_editing': return 'Đang sửa tiện ích bổ trợ cho hồ sơ';
			case 'creator_export_card': return 'Tạo thẻ';
			case 'info_enhancements': return 'Tiện ích bổ trợ tự động hóa việc chỉnh sửa trường trước khi tạo thẻ. Chọn một ô ở bên phải trường để cho phép sử dụng tiện ích bổ trợ. Mỗi trường có thể dùng tối đa năm ô bên phải. Tiện ích bổ trợ ở ô bên trái của trường sẽ tự động được áp dụng khi tạo thẻ tức thì hoặc mở Trình tạo thẻ.';
			case 'info_actions': return 'Thao tác nhanh cho phép tạo thẻ tức thì và dùng các tính năng tự động khác trên kết quả tìm kiếm từ điển. Có thể gán thao tác qua các ô bên dưới. Có thể dùng tối đa sáu ô.';
			case 'no_more_available_enhancements': return 'Không còn tiện ích bổ trợ nào cho trường này';
			case 'no_more_available_quick_actions': return 'Không còn thao tác nhanh nào';
			case 'assign_auto_enhancement': return 'Gán tiện ích bổ trợ tự động';
			case 'assign_manual_enhancement': return 'Gán tiện ích bổ trợ thủ công';
			case 'remove_enhancement': return 'Xóa tiện ích bổ trợ';
			case 'copy_of_mapping': return ({required Object name}) => 'Bản sao của ${name}';
			case 'enter_search_term': return 'Nhập từ cần tìm...';
			case 'searching_for': return ({required Object searchTerm}) => 'Đang tìm 『${searchTerm}』...';
			case 'no_search_results': return 'Không tìm thấy kết quả tìm kiếm.';
			case 'edit_actions': return 'Sửa thao tác nhanh của từ điển';
			case 'remove_action': return 'Xóa thao tác';
			case 'assign_action': return 'Gán thao tác';
			case 'dictionary_import_tag': return ({required Object name}) => 'Được nhập từ ${name}';
			case 'stash_added_single': return ({required Object term}) => 'Đã thêm 『${term}』 vào Kho tạm.';
			case 'stash_added_multiple': return 'Đã thêm nhiều mục vào Kho tạm.';
			case 'stash_clear_single': return ({required Object term}) => 'Đã xóa 『${term}』 khỏi Kho tạm.';
			case 'stash_clear_title': return 'Xóa Kho tạm';
			case 'stash_clear_description': return 'Tất cả nội dung sẽ bị xóa. Bạn có chắc không?';
			case 'stash_placeholder': return 'Không có mục nào trong Kho tạm';
			case 'stash_nothing_to_pop': return 'Không có mục nào để lấy khỏi Kho tạm.';
			case 'no_sentences_found': return 'Không tìm thấy câu nào';
			case 'failed_online_service': return 'Không thể giao tiếp với dịch vụ trực tuyến';
			case 'search_label_before': return 'Hiện tất cả ';
			case 'search_label_middle': return 'trong số ';
			case 'search_label_after': return 'kết quả tìm kiếm cho';
			case 'clear_dictionary_title': return 'Xóa lịch sử kết quả từ điển';
			case 'clear_dictionary_description': return 'Thao tác này sẽ xóa tất cả kết quả từ điển khỏi lịch sử. Bạn có chắc không?';
			case 'clear_search_title': return 'Xóa lịch sử tìm kiếm';
			case 'clear_search_description': return 'Thao tác này sẽ xóa tất cả từ khóa tìm kiếm trong lịch sử này. Bạn có chắc không?';
			case 'clear_creator_title': return 'Xóa Trình tạo';
			case 'clear_creator_description': return 'Thao tác này sẽ xóa tất cả các trường. Bạn có chắc không?';
			case 'copied_to_clipboard': return 'Đã sao chép vào bộ nhớ tạm.';
			case 'no_text': return 'Không có văn bản.';
			case 'info_fields': return 'Các trường được điền sẵn dựa trên mục từ được chọn khi xuất tức thì hoặc trước khi mở Trình tạo thẻ. Để đưa một trường vào thẻ xuất, bạn phải bật trường đó bên dưới và gán trường trong hồ sơ xuất hiện tại. Các trường đã bật cũng có thể được thu gọn bên dưới để giảm phần rối mắt khi chỉnh sửa. Dùng nút Xóa ở góc trên bên phải của Trình tạo thẻ để nhanh chóng xóa các trường ẩn này khi chỉnh sửa thẻ thủ công.';
			case 'edit_fields': return 'Sửa và sắp xếp lại các trường';
			case 'remove_field': return 'Xóa trường';
			case 'add_field': return 'Gán trường';
			case 'add_field_hint': return 'Gán một trường cho hàng này';
			case 'no_more_available_fields': return 'Không còn trường nào';
			case 'hidden_fields': return 'Các trường bổ sung';
			case 'field_fallback_used': return ({required Object field, required Object secondField}) => 'Trường ${field} đã dùng ${secondField} làm từ khóa tìm kiếm dự phòng.';
			case 'no_text_to_search': return 'Không có văn bản để tìm kiếm.';
			case 'image_search_label_before': return 'Đang chọn ảnh ';
			case 'image_search_label_middle': return 'trong số ';
			case 'image_search_label_after': return 'ảnh tìm thấy cho';
			case 'image_search_label_none_middle': return 'ảnh nào ';
			case 'image_search_label_none_before': return 'Chưa chọn ';
			case 'preparing_instant_export': return 'Đang chuẩn bị thẻ để xuất...';
			case 'processing_in_progress': return 'Đang chuẩn bị ảnh';
			case 'searching_in_progress': return 'Đang tìm kiếm ';
			case 'audio_unavailable': return 'Không tìm thấy âm thanh.';
			case 'no_audio_enhancements': return 'Chưa gán tiện ích bổ trợ âm thanh nào.';
			case 'card_exported': return ({required Object deck}) => 'Đã xuất thẻ vào 『${deck}』.';
			case 'info_incognito_on': return 'Đã bật chế độ ẩn danh. Lịch sử từ điển, nội dung và tìm kiếm sẽ không được ghi lại.';
			case 'info_incognito_off': return 'Đã tắt chế độ ẩn danh. Lịch sử từ điển, nội dung và tìm kiếm sẽ được ghi lại.';
			case 'exit_media_title': return 'Thoát nội dung';
			case 'exit_media_description': return 'Bạn sẽ được đưa về menu chính. Bạn có chắc không?';
			case 'unimplemented_source': return 'Nguồn chưa được triển khai';
			case 'clear_browser_title': return 'Xóa dữ liệu trình duyệt';
			case 'clear_browser_description': return 'Thao tác này sẽ xóa tất cả dữ liệu duyệt web được các nguồn nội dung web sử dụng. Bạn có chắc không?';
			case 'ttu_no_books_added': return 'Chưa thêm sách nào vào ッツ Ebook Reader';
			case 'local_media_directory_empty': return 'Thư mục không có thư mục con hoặc video';
			case 'pick_video_file': return 'Chọn tệp video';
			case 'navigate_up_one_directory_level': return 'Lên một cấp thư mục';
			case 'play': return 'Phát';
			case 'pause': return 'Tạm dừng';
			case 'record': return 'Ghi';
			case 'stop': return 'Dừng';
			case 'replay': return 'Phát lại';
			case 'audio_subtitles': return 'Âm thanh/Phụ đề';
			case 'player_option_shadowing': return 'Chế độ shadowing';
			case 'player_option_change_mode': return 'Đổi chế độ phát';
			case 'player_option_listening_comprehension': return 'Chế độ nghe hiểu';
			case 'player_option_drag_to_select': return 'Kéo để chọn phụ đề';
			case 'player_option_tap_to_select': return 'Chạm để chọn phụ đề';
			case 'player_option_dictionary_menu': return 'Chọn nguồn từ điển đang dùng';
			case 'player_option_cast_video': return 'Truyền tới thiết bị hiển thị';
			case 'player_option_share_subtitle': return 'Chia sẻ phụ đề hiện tại';
			case 'player_option_export': return 'Tạo thẻ từ ngữ cảnh';
			case 'player_option_audio': return 'Âm thanh';
			case 'player_option_subtitle': return 'Phụ đề';
			case 'player_option_subtitle_external': return 'Bên ngoài';
			case 'player_option_subtitle_none': return 'Không có';
			case 'player_option_select_subtitle': return 'Chọn kênh phụ đề';
			case 'player_option_select_audio': return 'Chọn kênh âm thanh';
			case 'player_option_text_filter': return 'Dùng bộ lọc biểu thức chính quy';
			case 'player_option_blur_preferences': return 'Tùy chọn khung làm mờ';
			case 'player_option_blur_use': return 'Dùng khung làm mờ';
			case 'player_option_blur_radius': return 'Bán kính làm mờ';
			case 'player_option_blur_options': return 'Đặt màu và độ mờ của khung làm mờ';
			case 'player_option_blur_reset': return 'Đặt lại kích thước và vị trí khung làm mờ';
			case 'player_align_subtitle_transcript': return 'Căn phụ đề với bản chép lời';
			case 'player_option_subtitle_appearance': return 'Thời gian và giao diện phụ đề';
			case 'player_option_load_subtitles': return 'Tải phụ đề bên ngoài';
			case 'player_option_subtitle_delay': return 'Độ trễ phụ đề';
			case 'player_option_audio_allowance': return 'Thời gian đệm âm thanh';
			case 'player_option_font_name': return 'Tên phông chữ phụ đề';
			case 'player_option_font_size': return 'Cỡ chữ phụ đề';
			case 'player_option_regex_filter': return 'Bộ lọc biểu thức chính quy';
			case 'player_option_subtitle_background_opacity': return 'Độ đục nền phụ đề';
			case 'player_option_subtitle_background_blur_radius': return 'Bán kính làm mờ nền phụ đề';
			case 'player_option_outline_width': return 'Độ rộng viền phụ đề';
			case 'player_option_subtitle_always_above_bottom_bar': return 'Luôn hiển thị phụ đề phía trên khu vực thanh dưới';
			case 'player_subtitles_transcript_empty': return 'Bản chép lời trống.';
			case 'player_prepare_export': return 'Đang chuẩn bị thẻ...';
			case 'player_change_player_orientation': return 'Đổi hướng trình phát';
			case 'no_current_media': return 'Phát hoặc làm mới nội dung để xem lời bài hát';
			case 'lyrics_permission_required': return 'Chưa được cấp quyền cần thiết';
			case 'no_lyrics_found': return 'Không tìm thấy lời bài hát';
			case 'trending': return 'Thịnh hành';
			case 'caption_filter': return 'Lọc phụ đề';
			case 'captions_query': return 'Đang tìm phụ đề';
			case 'captions_target': return 'Ngôn ngữ đích';
			case 'captions_app': return 'Ngôn ngữ ứng dụng';
			case 'captions_other': return 'Ngôn ngữ khác';
			case 'captions_closed': return 'Phụ đề do người tạo';
			case 'captions_auto': return 'Phụ đề tự động';
			case 'captions_unavailable': return 'Không có phụ đề';
			case 'captions_error': return 'Lỗi khi tìm phụ đề';
			case 'change_quality': return 'Đổi chất lượng';
			case 'closed_captions_query': return 'Đang tìm phụ đề';
			case 'closed_captions_target': return 'Phụ đề ngôn ngữ đích';
			case 'closed_captions_app': return 'Phụ đề bằng ngôn ngữ ứng dụng';
			case 'closed_captions_other': return 'Phụ đề bằng ngôn ngữ khác';
			case 'closed_captions_unavailable': return 'Không có phụ đề';
			case 'closed_captions_error': return 'Lỗi khi tìm phụ đề';
			case 'stream_url': return 'URL luồng phát';
			case 'default_option': return 'Mặc định';
			case 'paste': return 'Dán';
			case 'select_all': return 'Chọn tất cả';
			case 'lyrics_title': return 'Tên bài';
			case 'lyrics_artist': return 'Nghệ sĩ';
			case 'set_media': return 'Đặt nội dung';
			case 'no_recordings_found': return 'Không tìm thấy bản ghi nào';
			case 'wrap_image_audio': return 'Thêm thẻ HTML hình ảnh/âm thanh khi xuất';
			case 'server_address': return 'Địa chỉ máy chủ';
			case 'no_active_connection': return 'Không có kết nối đang hoạt động';
			case 'failed_server_connection': return 'Không thể kết nối với máy chủ';
			case 'no_text_received': return 'Chưa nhận được văn bản';
			case 'text_segmentation': return 'Phân đoạn văn bản';
			case 'connect_disconnect': return 'Kết nối/Ngắt kết nối';
			case 'clear_text_title': return 'Xóa văn bản';
			case 'clear_text_description': return 'Thao tác này sẽ xóa tất cả văn bản đã nhận. Bạn có chắc không?';
			case 'close_connection_title': return 'Đóng kết nối';
			case 'close_connection_description': return 'Thao tác này sẽ kết thúc kết nối WebSocket và xóa tất cả văn bản đã nhận. Bạn có chắc không?';
			case 'use_slow_import': return 'Nhập chậm (dùng nếu nhập lỗi)';
			case 'settings': return 'Cài đặt';
			case 'manager': return 'Trình quản lý';
			case 'volume_button_page_turning': return 'Dùng nút âm lượng để chuyển trang';
			case 'invert_volume_buttons': return 'Đảo nút âm lượng';
			case 'volume_button_turning_speed': return 'Tốc độ cuộn liên tục';
			case 'extend_page_beyond_navbar': return 'Mở rộng trang qua thanh điều hướng';
			case 'tweaks': return 'Tinh chỉnh';
			case 'increase': return 'Tăng';
			case 'decrease': return 'Giảm';
			case 'unit_milliseconds': return 'ms';
			case 'unit_pixels': return 'px';
			case 'dictionary_settings': return 'Cài đặt từ điển';
			case 'auto_search': return 'Tìm kiếm tự động';
			case 'auto_search_debounce_delay': return 'Độ trễ trước khi tự tìm';
			case 'dictionary_font_size': return 'Cỡ chữ từ điển';
			case 'close_on_export': return 'Đóng khi xuất';
			case 'close_on_export_on': return 'Trình tạo thẻ sẽ tự động đóng sau khi xuất thẻ.';
			case 'close_on_export_off': return 'Trình tạo thẻ sẽ không còn tự động đóng sau khi xuất thẻ.';
			case 'export_profile_empty': return 'Hồ sơ xuất của bạn chưa có trường nào được đặt và cần được cấu hình.';
			case 'error_export_media_ankidroid': return 'Đã xảy ra lỗi khi xuất nội dung vào AnkiDroid.';
			case 'error_add_note': return 'Đã xảy ra lỗi khi thêm thẻ vào AnkiDroid.';
			case 'first_time_setup': return 'Thiết lập lần đầu';
			case 'first_time_setup_description': return 'Chào mừng đến với jidoujisho! Hãy đặt ngôn ngữ đích và một hồ sơ mặc định sẽ được tùy chỉnh cho bạn. Bạn có thể thay đổi tùy chọn này bất cứ lúc nào.';
			case 'maximum_entries': return 'Giới hạn tối đa số mục từ điển được truy vấn';
			case 'maximum_terms': return 'Số từ đầu mục tối đa trong kết quả';
			case 'use_br_tags': return 'Dùng <br> thay cho ký tự xuống dòng khi xuất';
			case 'prepend_dictionary_names': return 'Thêm tên từ điển vào trước nghĩa';
			case 'highlight_on_tap': return 'Tô sáng văn bản khi chạm';
			case 'no_audio_file': return 'Không có tệp âm thanh để lưu.';
			case 'storage_permissions': return 'Vui lòng cấp các quyền sau để xuất vào AnkiDroid.';
			case 'stream': return 'Luồng phát';
			case 'network_subtitles_warning': return 'Không hỗ trợ phụ đề nhúng cho luồng mạng.';
			case 'accessibility': return 'Cần có quyền để chụp văn bản từ các sự kiện hỗ trợ tiếp cận.';
			case 'comments': return 'Bình luận';
			case 'replies': return 'Phản hồi';
			case 'no_comments_queried': return 'Không tìm thấy bình luận nào';
			case 'no_text_in_clipboard': return 'Không có văn bản để hiển thị';
			case 'file_downloaded': return ({required Object name}) => 'Đã tải tệp xuống: ${name}';
			case 'cfhange_sort_order': return 'Đổi thứ tự sắp xếp';
			case 'login': return 'Đăng nhập';
			case 'send': return 'Gửi';
			case 'no_messages': return 'Bắt đầu trò chuyện';
			case 'enter_message': return 'Nhập tin nhắn...';
			case 'clear_message_title': return 'Xóa tin nhắn';
			case 'clear_message_description': return 'Thao tác này sẽ xóa tất cả tin nhắn và bắt đầu cuộc trò chuyện mới. Bạn có chắc không?';
			case 'error_chatgpt_response': return 'Yêu cầu không thành công hoặc đã bị giới hạn tần suất. Hãy thử lại sau ít phút hoặc kiểm tra giới hạn sử dụng của bạn.';
			case 'pick_file': return 'Chọn tệp';
			case 'open_url': return 'Mở URL';
			case 'catalogs': return 'Danh mục';
			case 'name': return 'Tên';
			case 'url': return 'URL';
			case 'duplicate_catalog': return 'Đã có danh mục với URL này.';
			case 'no_catalogs_listed': return 'Không có danh mục nào';
			case 'go_back': return 'Quay lại';
			case 'invalid_mokuro_file': return 'Tệp không phải là tệp HTML do Mokuro tạo.';
			case 'create_catalog': return 'Tạo danh mục';
			case 'adapt_ttu_theme': return 'Điều chỉnh cửa sổ bật lên của từ điển theo giao diện';
			case 'sentence_picker': return 'Chọn câu';
			case 'field_locked': return ({required Object field}) => 'Trường ${field} đã khóa và sẽ không bị xóa khi xuất trong lúc Trình tạo đang hoạt động.';
			case 'field_unlocked': return ({required Object field}) => 'Trường ${field} đã mở khóa và sẽ bị xóa khi xuất.';
			case 'field_lock': return 'Khóa trường';
			case 'field_unlock': return 'Mở khóa trường';
			case 'use_dark_theme': return 'Dùng giao diện tối';
			case 'stretch_to_fill_screen': return 'Kéo giãn để lấp đầy màn hình';
			case 'processing_embedded_subtitles': return 'Đang xử lý phụ đề nhúng. Hãy thử lại sau.';
			case 'transcript_playback_mode': return 'Chế độ phát bản chép lời';
			case 'toggle_transcript_background': return 'Bật/tắt nền bản chép lời';
			case 'seek': return 'Tua';
			case 'saved_tags': return 'Đã lưu nhãn.';
			case 'structured_content_first': return ({required Object i}) => '${i} định nghĩa không được hỗ trợ và đã bị lược bỏ.';
			case 'structured_content_second': return 'Hãy thử dùng phiên bản nội dung không có cấu trúc của từ điển này.';
			case 'missing_api_key': return 'Chưa cung cấp khóa API';
			case 'chatgpt_error': return 'Đã xảy ra lỗi khi nhận phản hồi từ ChatGPT.';
			case 'api_key': return 'Khóa API';
			case 'subtitle_delay_set': return ({required Object ms}) => 'Đã đặt độ trễ phụ đề thành ${ms} ms.';
			case 'cancel': return 'Hủy';
			case 'server_port_in_use': return 'Cổng máy chủ cục bộ đang được sử dụng';
			case 'google_fonts': return 'Google Fonts';
			case 'video_show': return 'Hiện video';
			case 'video_hide': return 'Ẩn video';
			case 'subtitle_timing_show': return 'Hiện thời gian phụ đề';
			case 'subtitle_timing_hide': return 'Ẩn thời gian phụ đề';
			case 'find_next': return 'Tìm tiếp';
			case 'find_previous': return 'Tìm trước';
			case 'shadowing_mode': return 'Chế độ shadowing';
			case 'display_settings': return 'Cài đặt hiển thị';
			case 'cloze': return 'Điền chỗ trống';
			case 'info_standard_update': return 'Loại thẻ hồ sơ tiêu chuẩn mới';
			case 'info_standard_update_content': return 'Hồ sơ tiêu chuẩn hiện dùng loại thẻ 『jidoujisho Kinomoto』.\n\nHồ sơ tiêu chuẩn cũ của bạn vẫn có thể sử dụng để đảm bảo tương thích ngược.';
			case 'retrying_in.seconds': return ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('vi'))(n,
				one: 'Đang thử lại sau ${n} giây...',
				other: 'Đang thử lại sau ${n} giây...',
			);
			case 'view_replies.reply': return ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('vi'))(n,
				one: 'HIỆN ${n} PHẢN HỒI',
				other: 'HIỆN ${n} PHẢN HỒI',
			);
			case 'manage_duplicate_checks': return 'Quản lý kiểm tra trùng lặp';
			case 'playback_normal': return 'Chế độ phát bình thường';
			case 'playback_condensed': return 'Chế độ phát cô đọng';
			case 'playback_auto_pause': return 'Chế độ phát tạm dừng theo phụ đề';
			case 'player_hardware_acceleration': return 'Tăng tốc phần cứng';
			case 'player_use_opensles': return 'Âm thanh OpenSL ES';
			case 'go_forward': return 'Đi tới';
			case 'browse': return 'Duyệt';
			case 'bookmark': return 'Dấu trang';
			case 'add_bookmark': return 'Thêm dấu trang';
			case 'add_to_reading_list': return 'Thêm vào danh sách đọc';
			case 'reading_list_empty': return 'Danh sách đọc trống';
			case 'reading_list_add_toast': return 'Đã thêm vào danh sách đọc.';
			case 'reading_list_remove_toast': return 'Đã xóa khỏi danh sách đọc.';
			case 'ad_block_hosts': return 'Danh sách chặn quảng cáo (hosts)';
			case 'error_parsing_hosts_file': return 'Lỗi khi phân tích tệp hosts.';
			case 'double_tap_seek_duration': return 'Thời lượng tua khi chạm hai lần';
			case 'player_background_play': return 'Phát trong nền';
			case 'loaded_from_cache': return 'Đã tải từ bộ nhớ đệm lưu trữ web.';
			case 'player_show_subtitle_in_notification': return 'Hiện phụ đề trong thông báo nội dung';
			case 'subtitles_processing': return 'Đang xử lý phụ đề...';
			case 'video_unavailable': return 'Video không khả dụng';
			case 'video_unavailable_content': return 'Không thể lấy các luồng phát. Có thể có hạn chế khiến bạn không thể xem video này.';
			case 'video_file_error': return 'Không thể tải tệp';
			case 'video_file_error_content': return 'Không thể tải tệp video. Hãy đảm bảo tệp này tồn tại và nằm trong thư mục mà ứng dụng có thể truy cập.';
			case 'ttu_add': return 'Thêm';
			case 'ttu_add_book': return 'Thêm sách';
			case 'ttu_reader_settings': return 'Cài đặt trình đọc';
			case 'ttu_reader_source': return 'Nguồn trình đọc';
			case 'ttu_empty_title': return 'Thư viện của bạn đang trống';
			case 'ttu_empty_body': return 'Thêm tệp EPUB hoặc HTMLZ để bắt đầu đọc. Chạm vào bất kỳ từ nào để tra từ khi đọc.';
			case 'ttu_restore_backup': return 'Khôi phục từ bản sao lưu';
			case 'ttu_adding_book': return ({required Object name}) => 'Đang thêm ${name}';
			case 'ttu_adding_books': return ({required Object n}) => 'Đang thêm ${n} sách';
			case 'ttu_reading_file': return 'ッツ đang đọc tệp';
			case 'ttu_added_book': return ({required Object name}) => 'Đã thêm ${name}';
			case 'ttu_added_books': return ({required Object n}) => 'Đã thêm ${n} sách';
			case 'ttu_import_failed': return ({required Object reason}) => 'Không thể thêm sách: ${reason}';
			case 'ttu_unsupported_file': return ({required Object name}) => '${name} không phải là tệp EPUB hoặc HTMLZ';
			case 'ttu_shelf_error': return 'Không thể đọc thư viện.';
			case 'ttu_try_again': return 'Thử lại';
			case 'ttu_book_deleted': return ({required Object name}) => 'Đã xóa ${name}';
			case 'ttu_undo': return 'Hoàn tác';
			case 'ttu_read': return 'Đọc';
			case 'ttu_continue': return 'Tiếp tục';
			case 'ttu_memo': return 'Ghi chú';
			case 'ttu_memos': return 'Ghi chú';
			case 'ttu_new_memo': return 'Ghi chú mới';
			case 'ttu_edit_memo': return 'Sửa ghi chú';
			case 'ttu_memo_placeholder': return 'Một từ cần tra, một câu hỏi, lý do dòng này quan trọng';
			case 'ttu_memo_saved': return ({required Object position}) => 'Đã lưu ghi chú tại ${position}';
			case 'ttu_memo_deleted': return 'Đã xóa ghi chú';
			case 'ttu_no_memos': return 'Chưa có ghi chú. Chọn văn bản trong sách rồi chạm vào Ghi chú để thêm.';
			case 'ttu_no_memos_short': return 'Chưa có ghi chú';
			case 'ttu_memo_hint': return 'Thêm ghi chú khi đọc: chọn văn bản rồi chạm vào Ghi chú.';
			case 'ttu_continue_reading': return 'Đọc tiếp';
			case 'ttu_back_to_where': return 'Quay lại vị trí trước đó';
			case 'ttu_before_jump': return 'trước lần chuyển cuối';
			case 'ttu_sort_position': return 'Vị trí';
			case 'ttu_sort_newest': return 'Mới nhất';
			case 'ttu_read_percent': return ({required Object percent}) => 'Đã đọc ${percent}';
			case 'ttu_edit': return 'Sửa';
			case 'ttu_delete': return 'Xóa';
			case 'ttu_progress': return 'Tiến độ';
			case 'ttu_read_label': return 'Đã đọc';
			case 'ttu_of_total': return ({required Object total}) => 'trên ${total}';
			case 'ttu_last_opened': return 'Mở lần cuối';
			case 'ttu_not_opened': return 'Chưa mở';
			case 'ttu_added_when': return ({required Object when}) => 'Đã thêm ${when}';
			case 'ttu_language': return 'Ngôn ngữ';
			case 'ttu_uses_dictionaries': return 'Tra từ bằng ngôn ngữ này';
			case 'ttu_page': return 'Trang';
			case 'ttu_page_note': return 'ッツ áp dụng các cài đặt này khi mở sách';
			case 'ttu_books_in': return ({required Object language}) => 'Sách bằng ${language}';
			case 'ttu_theme': return 'Chủ đề';
			case 'ttu_text_size': return 'Cỡ chữ';
			case 'ttu_direction': return 'Hướng chữ';
			case 'ttu_vertical': return 'Dọc';
			case 'ttu_horizontal': return 'Ngang';
			case 'ttu_layout': return 'Bố cục';
			case 'ttu_pages': return 'Trang';
			case 'ttu_scroll': return 'Cuộn';
			case 'ttu_furigana': return 'Hiện Furigana';
			case 'ttu_furigana_desc': return 'Cách đọc bên trên kanji, nếu sách có';
			case 'ttu_while_reading': return 'Khi đọc';
			case 'ttu_auto_save': return 'Lưu vị trí của tôi';
			case 'ttu_auto_save_desc': return 'Lưu khi bạn đọc và khi bạn rời khỏi sách';
			case 'ttu_highlight': return 'Tô sáng từ đã tra';
			case 'ttu_highlight_desc': return 'Đánh dấu từ mà từ điển đã tra';
			case 'ttu_volume': return 'Phím âm lượng chuyển trang';
			case 'ttu_volume_desc': return 'Mỗi lần nhấn chuyển một trang';
			case 'ttu_volume_swap': return 'Đổi phím âm lượng';
			case 'ttu_volume_swap_desc': return 'Nếu các phím hoạt động ngược chiều';
			case 'ttu_scroll_step': return 'Bước cuộn';
			case 'ttu_scroll_step_desc': return 'Khoảng cuộn sau mỗi lần nhấn phím trong bố cục Cuộn';
			case 'ttu_full_screen': return 'Toàn màn hình';
			case 'ttu_full_screen_desc': return 'Hiển thị bên dưới thanh trạng thái. Phù hợp nhất với điện thoại không có tai thỏ';
			case 'ttu_match_popup': return 'Cửa sổ bật lên khớp với trang';
			case 'ttu_match_popup_desc': return 'Dùng chủ đề của trang cho cửa sổ bật lên';
			case 'ttu_more': return 'Thêm';
			case 'ttu_backup_sync': return 'Sao lưu và đồng bộ';
			case 'ttu_backup_sync_desc': return 'Google Drive, OneDrive hoặc một thư mục. Mở ッツ';
			case 'ttu_all_settings': return 'Tất cả cài đặt ッツ';
			case 'ttu_all_settings_desc': return 'Phông chữ, lề, cột trang và nhiều cài đặt khác. Mở ッツ';
			case 'ttu_opening': return 'Đang mở';
			case 'ttu_jumping_to': return 'Đang chuyển đến';
			case 'ttu_returning_to': return 'Quay lại';
			case 'ttu_back_to': return ({required Object position}) => 'Quay lại ${position}';
			case 'ttu_saved_place': return ({required Object position}) => 'Đã lưu vị trí của bạn tại ${position}';
			case 'ttu_just_now': return 'Vừa xong';
			case 'ttu_minutes_ago': return ({required Object n}) => '${n} phút trước';
			case 'ttu_today': return 'Hôm nay';
			case 'ttu_yesterday': return 'Hôm qua';
			case 'ttu_days_ago': return ({required Object n}) => '${n} ngày trước';
			case 'ttu_week_ago': return '1 tuần trước';
			case 'ttu_weeks_ago': return ({required Object n}) => '${n} tuần trước';
			case 'ttu_month_ago': return '1 tháng trước';
			case 'ttu_months_ago': return ({required Object n}) => '${n} tháng trước';
			case 'my_words': return 'Mục từ của tôi';
			case 'my_words_add': return 'Thêm vào Mục từ của tôi';
			case 'my_words_edit': return 'Sửa mục từ';
			case 'my_words_word': return 'Mục từ';
			case 'my_words_reading': return 'Cách đọc';
			case 'my_words_meaning': return 'Nghĩa (tùy chọn)';
			case 'my_words_meaning_hint': return 'Tạo sinh tăng cường truy xuất';
			case 'my_words_saved': return 'Đã lưu vào Mục từ của tôi';
			case 'my_words_deleted': return 'Đã xóa mục từ';
			case 'my_words_empty': return 'Chưa có mục từ';
			case 'my_words_info': return 'Nghĩa do bạn tự thêm. Chúng luôn hiển thị đầu tiên mỗi khi bạn tra mục từ, trong bất kỳ cuốn sách nào. Chọn văn bản như "software as a service (SaaS)" rồi chạm vào Thêm mục từ để lưu SaaS chỉ với một lần chạm.';
			case 'my_words_new': return 'Mục từ mới';
			case 'add_word': return 'Thêm mục từ';
			case 'ttu_page_info': return 'Sách bằng ngôn ngữ này sẽ mở với các cài đặt này.';
			case 'ttu_font': return 'Phông chữ';
			case 'ttu_font_serif': return 'Serif';
			case 'ttu_font_sans': return 'Sans';
			case 'ttu_font_mincho': return 'Mincho';
			case 'ttu_font_klee': return 'Klee';
			case 'ttu_line_spacing': return 'Giãn dòng';
			case 'ttu_margins': return 'Lề';
			case 'ttu_columns': return 'Cột';
			case 'ttu_columns_auto': return 'Tự động';
			case 'ttu_furigana_label': return 'Furigana';
			case 'ttu_furigana_show': return 'Hiện';
			case 'ttu_furigana_faded': return 'Mờ';
			case 'ttu_furigana_hidden': return 'Ẩn';
			case 'ttu_furigana_tap': return 'Khi chạm';
			case 'ttu_furigana_info': return 'Mờ hiển thị cách đọc bằng màu xám. Khi chạm hiển thị cách đọc lúc bạn chạm vào một từ.';
			case 'ttu_avoid_break': return 'Giữ nguyên đoạn văn';
			case 'ttu_avoid_break_info': return 'Chuyển đoạn văn sang trang tiếp theo thay vì chia đoạn.';
			case 'ttu_blur_images': return 'Làm mờ hình ảnh';
			case 'ttu_blur_images_info': return 'Ẩn hình ảnh sau lớp che spoiler cho đến khi bạn chạm vào chúng.';
			case 'ttu_full_screen_info': return 'Ẩn thanh trạng thái và thanh điều hướng. Khi vuốt từ cạnh màn hình, chúng chỉ hiện ra, vì vậy bạn cần vuốt hai lần để thoát hoặc mở thông báo.';
			case 'ttu_camera_area': return 'Dùng vùng camera';
			case 'ttu_camera_area_info': return 'Cho phép trang hiển thị bên dưới phần khoét camera.';
			case 'ttu_keep_screen_on': return 'Giữ màn hình luôn bật';
			case 'ttu_auto_save_info': return 'Lưu khi bạn đọc và khi bạn rời khỏi sách.';
			case 'ttu_match_popup_info': return 'Dùng chủ đề của trang cho cửa sổ tra từ bật lên.';
			case 'ttu_scroll_step_info': return 'Khoảng cuộn sau mỗi lần nhấn phím trong bố cục Cuộn.';
			case 'file_access_title': return 'Cho phép truy cập tệp?';
			case 'file_access_media': return 'Ảnh, video và âm thanh';
			case 'file_access_all': return 'Tất cả tệp';
			case 'file_access_allow': return 'Cho phép';
			case 'file_access_not_now': return 'Để sau';
			case 'file_access_info': return 'Cần quyền này để mở video và manga từ các thư mục trên điện thoại. Ảnh, video và âm thanh là đủ để phát video; Tất cả tệp cũng tìm thấy các tệp phụ đề bên cạnh chúng. Sách và từ điển không bao giờ cần quyền này.';
			case 'file_access_info_short': return 'Cần quyền này để mở video và manga từ các thư mục trên điện thoại. Sách và từ điển không bao giờ cần quyền này.';
			case 'file_access_denied': return 'Không thể mở tệp nếu chưa được cấp quyền truy cập. Bạn có thể cho phép trong phần cài đặt Android.';
			case 'ttu_language_changed': return ({required Object language}) => 'Các từ trong sách này hiện được tra bằng ${language}';
			case 'my_terms_from': return ({required Object title}) => 'Từ ${title}';
			case 'my_terms_saved_term': return ({required Object term}) => 'Đã lưu ${term}';
			case 'my_terms_edit': return 'Sửa';
			case 'ttu_terms': return 'Mục từ';
			case 'ttu_no_terms': return 'Chưa có mục từ nào được lưu từ sách này';
			case 'ttu_place_kept': return ({required Object position}) => 'Vị trí của bạn vẫn là ${position}';
			case 'ttu_read_on': return 'Đọc';
			case 'ttu_font_genei': return 'Genei';
			case 'ttu_chapters': return 'Chương';
			case 'ttu_no_chapters': return 'Sách này không có danh sách chương';
			case 'ttu_applying': return 'Đang áp dụng cài đặt';
			case 'ttu_memos_on_page': return 'Hiện ghi chú trên trang';
			case 'ttu_memos_on_page_info': return 'Một dòng ngắn phía trên mỗi đoạn văn có ghi chú. Chạm vào để đọc toàn bộ ghi chú.';
			case 'ttu_color_amber': return 'Hổ phách';
			case 'ttu_color_rose': return 'Hồng';
			case 'ttu_color_green': return 'Xanh lá';
			case 'ttu_color_sky': return 'Xanh dương';
			case 'ttu_color_violet': return 'Tím';
			case 'catalog_title': return 'Từ điển trực tuyến';
			case 'catalog_open': return 'Trực tuyến';
			case 'catalog_connect_title': return 'Kết nối máy chủ từ điển';
			case 'catalog_connect_hint': return 'Dán địa chỉ máy chủ và token. Token chỉ đọc cho phép duyệt và tải xuống; token quản trị còn cho phép tải lên và xóa. Dán liên kết có token sau dấu # sẽ tự điền cả hai.';
			case 'catalog_address': return 'Địa chỉ máy chủ';
			case 'catalog_token': return 'Token';
			case 'catalog_connect': return 'Kết nối';
			case 'catalog_all': return 'Tất cả';
			case 'catalog_section_bilingual': return 'Song ngữ';
			case 'catalog_section_monolingual': return 'Đơn ngữ';
			case 'catalog_section_kanji': return 'Kanji';
			case 'catalog_section_frequency': return 'Tần suất';
			case 'catalog_section_pronunciation': return 'Phát âm';
			case 'catalog_section_other': return 'Khác';
			case 'catalog_entries': return ({required Object n}) => '${n} mục từ';
			case 'catalog_installed': return 'Đã cài đặt';
			case 'catalog_preparing': return 'Đang chuẩn bị';
			case 'catalog_failed': return 'Không thể chuẩn bị';
			case 'catalog_download': return 'Tải xuống';
			case 'catalog_search_hint': return 'Tìm trong từ điển này';
			case 'catalog_nothing_found': return ({required Object query}) => 'Không tìm thấy gì cho ${query}';
			case 'catalog_upload': return 'Tải lên';
			case 'catalog_uploading': return ({required Object name}) => 'Đang tải ${name} lên';
			case 'catalog_uploaded': return ({required Object name}) => '${name} đã có trên máy chủ và đang được chuẩn bị';
			case 'catalog_replace': return 'Thay thế';
			case 'catalog_delete': return 'Xóa khỏi máy chủ';
			case 'catalog_delete_confirm': return 'Chạm lần nữa để xóa';
			case 'catalog_deleted': return ({required Object name}) => 'Đã xóa ${name} khỏi máy chủ';
			case 'catalog_words': return 'Từ';
			case 'catalog_definitions': return 'Định nghĩa';
			case 'catalog_languages_hint': return 'Ngôn ngữ bạn tra từ và ngôn ngữ của phần định nghĩa. Các từ điển không có thông tin này trong chỉ mục sẽ được máy chủ gắn nhãn dựa trên nội dung; hãy sửa tại đây nếu máy chủ đoán sai.';
			case 'catalog_save': return 'Lưu';
			case 'catalog_server': return 'Máy chủ';
			case 'catalog_disconnect': return 'Ngắt kết nối';
			case 'catalog_role_admin': return 'Quản trị viên';
			case 'catalog_role_read': return 'Chỉ đọc';
			case 'catalog_empty': return 'Chưa có từ điển nào trên máy chủ';
			case 'catalog_imported': return ({required Object name}) => 'Đã nhập ${name}';
			case 'catalog_unknown_language': return 'Không xác định';
			case 'backup_title': return 'Sao lưu và khôi phục';
			case 'backup_menu': return 'Sao lưu và khôi phục';
			case 'backup_step_settings': return 'Cài đặt';
			case 'backup_step_memos': return 'Ghi chú và mục từ';
			case 'backup_step_books': return ({required Object language}) => 'Sách (${language})';
			case 'backup_step_dictionary': return ({required Object name}) => 'Từ điển: ${name}';
			case 'backup_step_packing': return 'Đang đóng gói';
			case 'backup_step_download': return ({required Object name}) => 'Đang tải ${name} xuống';
			case 'backup_step_install': return ({required Object name}) => 'Đang cài đặt ${name}';
			case 'backup_not_a_backup': return 'Tệp này không phải bản sao lưu jidoujisho.';
			case 'backup_too_new': return 'Bản sao lưu này được tạo bởi phiên bản ứng dụng mới hơn. Hãy cập nhật ứng dụng để khôi phục.';
			case 'backup_make': return 'Sao lưu';
			case 'backup_make_hint': return 'Một tệp chứa sách và vị trí đọc, cài đặt và phông chữ của ッツ, ghi chú, Mục từ của tôi, lịch sử, hồ sơ Anki, cài đặt ứng dụng cùng liên kết máy chủ từ điển và các từ điển của bạn. Khi khôi phục, các từ điển có trên máy chủ từ điển sẽ được tải xuống lại; các từ điển khác được lưu trong tệp. Tệp có chứa token máy chủ của bạn, hãy giữ kín tệp này.';
			case 'backup_restore': return 'Khôi phục';
			case 'backup_restore_hint': return 'Thay thế sách, ghi chú, mục từ và cài đặt trên thiết bị này bằng dữ liệu trong bản sao lưu. Các từ điển đã có trên thiết bị vẫn được giữ lại; những từ điển khác trong bản sao lưu sẽ được cài đặt.';
			case 'backup_choose': return 'Chọn bản sao lưu';
			case 'backup_saved': return 'Đã lưu bản sao lưu';
			case 'backup_not_saved': return 'Chưa lưu được bản sao lưu';
			case 'backup_books': return 'Sách';
			case 'backup_dictionaries': return 'Từ điển';
			case 'backup_dictionaries_split': return ({required Object included, required Object online}) => '${included} trong tệp · ${online} từ máy chủ của bạn';
			case 'backup_memos': return 'Ghi chú';
			case 'backup_terms': return 'Mục từ của tôi';
			case 'backup_made': return ({required Object date, required Object version}) => 'Được tạo ${date} bằng ${version}';
			case 'backup_restore_confirm': return 'Chạm lần nữa để thay thế dữ liệu trên thiết bị này';
			case 'backup_restored': return 'Đã khôi phục. Khởi động lại ứng dụng để hoàn tất.';
			case 'backup_restart': return 'Đóng ứng dụng';
			case 'backup_failed_dictionaries': return ({required Object names}) => 'Không thể cài đặt: ${names}';
			case 'backup_working': return 'Hãy giữ ứng dụng mở cho đến khi hoàn tất.';
			case 'theme_menu': return 'Chủ đề';
			case 'theme_mode': return 'Chế độ';
			case 'theme_mode_system': return 'Hệ thống';
			case 'theme_mode_light': return 'Sáng';
			case 'theme_mode_dark': return 'Tối';
			case 'theme_mode_hint': return 'Hệ thống làm theo điện thoại của bạn và chuyển đổi cùng điện thoại.';
			case 'theme_accent': return 'Màu nhấn';
			case 'theme_accent_red': return 'Đỏ';
			case 'theme_accent_rose': return 'Hồng';
			case 'theme_accent_orange': return 'Cam';
			case 'theme_accent_green': return 'Xanh lá';
			case 'theme_accent_teal': return 'Xanh ngọc';
			case 'theme_accent_blue': return 'Xanh dương';
			case 'theme_accent_violet': return 'Tím';
			case 'theme_accent_slate': return 'Xám xanh';
			case 'ttu_search': return 'Tìm kiếm';
			case 'ttu_search_hint': return 'Tìm trong sách này';
			case 'ttu_search_found': return ({required Object count}) => 'Tìm thấy ${count} kết quả';
			case 'ttu_search_first': return ({required Object shown}) => 'Hiển thị ${shown} kết quả đầu tiên';
			case 'ttu_search_none': return 'Không có trong sách này';
			case 'ttu_search_reading': return 'Đang đọc sách…';
			case 'ttu_search_stay': return 'Ở lại đây';
			case 'ttu_search_list': return 'Tất cả kết quả';
			case 'ttu_search_previous': return 'Kết quả trước';
			case 'ttu_search_next': return 'Kết quả tiếp theo';
			case 'ttu_search_info': return 'Kết quả không phân biệt hiragana và katakana, ký tự full-width và half-width, hay chữ hoa và chữ thường. Không tìm kiếm Furigana. Vị trí đã lưu vẫn giữ nguyên cho đến khi bạn chọn Ở lại đây.';
			case 'ttu_favourite': return 'Yêu thích';
			case 'ttu_unfavourite': return 'Xóa khỏi mục yêu thích';
			case 'ttu_favourites': return 'Mục yêu thích';
			case 'ttu_shelf': return 'Kệ sách';
			case 'ttu_group_by': return 'Nhóm theo';
			case 'ttu_group_by_none': return 'Không nhóm';
			case 'ttu_group_by_groups': return 'Nhóm của tôi';
			case 'ttu_group_by_language': return 'Ngôn ngữ';
			case 'ttu_group_by_progress': return 'Tiến độ';
			case 'ttu_group': return 'Nhóm';
			case 'ttu_group_none': return 'Không có';
			case 'ttu_ungrouped': return 'Chưa thuộc nhóm';
			case 'ttu_progress_reading': return 'Đang đọc';
			case 'ttu_progress_unread': return 'Chưa bắt đầu';
			case 'ttu_progress_finished': return 'Đã đọc xong';
			case 'ttu_other_books': return 'Sách';
			case 'ttu_new_group': return 'Nhóm mới';
			case 'ttu_group_name': return 'Tên nhóm';
			case 'ttu_rename_group': return 'Đổi tên';
			case 'ttu_delete_group': return 'Xóa nhóm';
			case 'ttu_group_info': return 'Sách sẽ hiển thị dưới nhóm khi kệ sách được nhóm theo Nhóm của tôi trong phần cài đặt kệ sách.';
			case 'ttu_group_by_info': return 'Mục yêu thích luôn hiển thị đầu tiên. Chạm vào tiêu đề để thu gọn.';
			case 'ttu_this_book': return 'Sách này';
			case 'ttu_follow_links': return 'Mở liên kết';
			case 'ttu_follow_links_info': return 'Khi bật, chạm vào liên kết sẽ đưa bạn đến nơi liên kết trỏ tới, kèm cách quay lại. Khi tắt, liên kết được đọc như văn bản thường và chạm vào sẽ tra từ.';
			case 'ttu_book_fonts': return 'Phông chữ riêng của sách';
			case 'ttu_book_fonts_info': return 'Khi tắt, phông chữ của bạn được dùng cho toàn bộ sách. Mã vẫn dùng phông chữ đơn cách.';
			case 'ttu_repaired_partly': return ({required Object title}) => 'Một phần của ${title} bị thiếu trong tệp. Phần còn lại đã được thêm.';
			case 'catalog_description': return 'Mô tả';
			case 'catalog_description_hint': return 'Dùng để làm gì hoặc dành cho ai';
			case 'catalog_description_shown_in': return ({required Object language}) => 'Chỉ hiển thị khi ứng dụng dùng ${language}';
			case 'import_replacing': return ({required Object name}) => 'Đang thay thế ${name} cũ…';
			case 'catalog_update': return 'Cập nhật lên phiên bản này';
			case 'dictionary_about': return 'Thông tin';
			case 'dictionary_by': return ({required Object author}) => 'Tác giả: ${author}';
			case 'dictionary_delete_all': return 'Xóa tất cả từ điển';
			case 'dictionary_import': return 'Nhập';
			case 'dictionary_collapsed': return 'Mặc định thu gọn';
			case 'dictionary_show_in_results': return 'Hiện trong kết quả';
			case 'dictionary_start_collapsed': return 'Thu gọn sẵn trong kết quả';
			case 'dictionary_from_server': return 'Đã tải xuống';
			case 'dictionary_from_file': return 'Đã nhập từ tệp';
			case 'dictionary_delete': return 'Xóa từ điển';
			case 'ttu_add_font': return 'Thêm phông chữ';
			case 'ttu_font_unsupported': return 'Phông chữ phải là tệp .ttf, .otf, .woff hoặc .woff2.';
			case 'ttu_font_failed': return 'Không thể thêm phông chữ.';
			case 'ttu_remove_font': return ({required Object name}) => 'Xóa ${name}';
			case 'auto_backup_title': return 'Luôn cập nhật bản sao lưu';
			case 'auto_backup_hint': return 'Một tệp sao lưu ở nơi bạn chọn, chẳng hạn như Google Drive, sẽ được ghi đè khi đến hạn để chỉ giữ lại bản mới nhất. Tệp được cập nhật khi ứng dụng đang mở, một lúc sau khi bạn mở ứng dụng.';
			case 'auto_backup_choose': return 'Chọn nơi lưu';
			case 'auto_backup_file': return 'Tệp sao lưu';
			case 'auto_backup_daily': return 'Mỗi ngày';
			case 'auto_backup_weekly': return 'Mỗi tuần';
			case 'auto_backup_own_dictionaries': return 'Bao gồm các từ điển do tôi tự thêm';
			case 'auto_backup_own_dictionaries_info': return 'Các từ điển này có thể khiến tệp lớn. Từ điển trên máy chủ của bạn luôn được liệt kê và sẽ được tải xuống lại khi khôi phục.';
			case 'auto_backup_now': return 'Cập nhật ngay';
			case 'auto_backup_off': return 'Tắt';
			case 'auto_backup_updated': return ({required Object date}) => 'Đã cập nhật ${date}';
			case 'auto_backup_never': return 'Chưa cập nhật';
			case 'auto_backup_failed': return ({required Object reason}) => 'Lần cập nhật cuối thất bại: ${reason}';
			case 'auto_backup_lost': return 'Không thể truy cập tệp sao lưu nữa. Hãy chọn lại nơi lưu.';
			case 'auto_backup_writing': return 'Đang ghi tệp sao lưu';
			case 'auto_backup_cannot_keep': return 'Sau này không thể ghi lại vào nơi đó. Hãy chọn nơi khác, chẳng hạn như một thư mục hoặc Google Drive.';
			case 'auto_backup_running': return 'Đang cập nhật tệp sao lưu';
			case 'ttu_tags': return 'Nhãn';
			case 'ttu_add_tag': return 'Thêm nhãn';
			case 'ttu_tags_none': return 'Chưa có nhãn';
			case 'ttu_tags_used_before': return 'Đã dùng trước đây';
			case 'ttu_tags_info': return 'Nhãn hiển thị trên bìa sách. Chọn một nhãn đã dùng trước đây hoặc nhập nhãn mới.';
			case 'ttu_theme_names.light': return 'Sáng';
			case 'ttu_theme_names.ecru': return 'Ngà';
			case 'ttu_theme_names.water': return 'Nước';
			case 'ttu_theme_names.gray': return 'Xám';
			case 'ttu_theme_names.dark': return 'Tối';
			case 'ttu_theme_names.black': return 'Đen';
			case 'language_names.ja': return 'Tiếng Nhật';
			case 'language_names.en': return 'Tiếng Anh';
			case 'language_names.vi': return 'Tiếng Việt';
			case 'language_names.zh': return 'Tiếng Trung';
			case 'language_names.ko': return 'Tiếng Hàn';
			case 'language_names.fr': return 'Tiếng Pháp';
			case 'language_names.de': return 'Tiếng Đức';
			case 'language_names.es': return 'Tiếng Tây Ban Nha';
			case 'language_names.ru': return 'Tiếng Nga';
			case 'language_names.th': return 'Tiếng Thái';
			case 'language_names.ar': return 'Tiếng Ả Rập';
			case 'addons.field.sentence.label': return 'Câu';
			case 'addons.field.sentence.description': return 'Phụ đề, đoạn trích trong sách và thông tin ngữ cảnh khác.';
			case 'addons.field.term.label': return 'Mục từ';
			case 'addons.field.term.description': return 'Từ đầu mục hoặc cụm từ trong từ điển.';
			case 'addons.field.reading.label': return 'Cách đọc';
			case 'addons.field.reading.description': return 'Cách phát âm hoặc kiểu nói.';
			case 'addons.field.meaning.label': return 'Nghĩa';
			case 'addons.field.meaning.description': return 'Tất cả định nghĩa trong từ điển của một mục từ.';
			case 'addons.field.notes.label': return 'Ghi chú';
			case 'addons.field.notes.description': return 'Thông tin bổ sung hoặc nhận xét cá nhân.';
			case 'addons.field.image.label': return 'Hình ảnh';
			case 'addons.field.image.description': return 'Thông tin bổ sung trực quan. Có thể dùng trường văn bản để nhập từ tìm kiếm cho các nguồn hình ảnh.';
			case 'addons.field.audio.label': return 'Âm thanh mục từ';
			case 'addons.field.audio.description': return 'Âm thanh liên quan đến mục từ. Có thể dùng trường văn bản để nhập từ tìm kiếm cho các nguồn âm thanh.';
			case 'addons.field.audio_sentence.label': return 'Âm thanh câu';
			case 'addons.field.audio_sentence.description': return 'Âm thanh liên quan đến câu. Có thể dùng trường văn bản để nhập từ tìm kiếm cho các nguồn âm thanh.';
			case 'addons.field.pitch_accent.label': return 'Trọng âm cao độ';
			case 'addons.field.pitch_accent.description': return 'Điền sẵn văn bản để xuất sơ đồ trọng âm cao độ.';
			case 'addons.field.furigana.label': return 'Furigana';
			case 'addons.field.furigana.description': return 'Điền sẵn văn bản để xuất Furigana.';
			case 'addons.field.frequency.label': return 'Tần suất';
			case 'addons.field.frequency.description': return 'Thêm tần suất của từ đầu mục để sắp xếp, được tính bằng trung bình điều hòa.';
			case 'addons.field.context.label': return 'Ngữ cảnh';
			case 'addons.field.context.description': return 'Tên của nguồn hiện tại.';
			case 'addons.field.cloze_before.label': return 'Trước chỗ trống';
			case 'addons.field.cloze_before.description': return 'Văn bản trước phần được tô sáng trong câu. Trống nếu không có gì được tô sáng.';
			case 'addons.field.cloze_inside.label': return 'Chỗ trống';
			case 'addons.field.cloze_inside.description': return 'Văn bản được tô sáng trong câu.';
			case 'addons.field.cloze_after.label': return 'Sau chỗ trống';
			case 'addons.field.cloze_after.description': return 'Văn bản sau phần được tô sáng trong câu. Trống nếu không có gì được tô sáng.';
			case 'addons.field.expanded_meaning.label': return 'Nghĩa mở rộng';
			case 'addons.field.expanded_meaning.description': return 'Chỉ các định nghĩa từ những từ điển đang mở rộng.';
			case 'addons.field.collapsed_meaning.label': return 'Nghĩa thu gọn';
			case 'addons.field.collapsed_meaning.description': return 'Chỉ các định nghĩa từ những từ điển đang thu gọn.';
			case 'addons.field.hidden_meaning.label': return 'Nghĩa ẩn';
			case 'addons.field.hidden_meaning.description': return 'Chỉ các định nghĩa từ những từ điển đang ẩn.';
			case 'addons.field.tags.label': return 'Nhãn';
			case 'addons.field.tags.description': return 'Sắp xếp thẻ trong bộ thẻ bằng các nhãn cách nhau bởi dấu cách.';
			case 'addons.enhancement.clear_field.label': return 'Xóa trường';
			case 'addons.enhancement.clear_field.description': return 'Nhanh chóng xóa nội dung của một trường.';
			case 'addons.enhancement.jpd101_audio.label': return 'Âm thanh JapanesePod101';
			case 'addons.enhancement.jpd101_audio.description': return 'Tìm cách phát âm phù hợp của từ trên JapanesePod101.';
			case 'addons.enhancement.forvo_audio.label': return 'Âm thanh Forvo';
			case 'addons.enhancement.forvo_audio.description': return 'Lấy âm thanh của từ từ Forvo.';
			case 'addons.enhancement.pick_audio.label': return 'Chọn âm thanh';
			case 'addons.enhancement.pick_audio.description': return 'Chọn tệp âm thanh bằng trình chọn bên ngoài.';
			case 'addons.enhancement.audio_recorder.label': return 'Trình ghi âm';
			case 'addons.enhancement.audio_recorder.description': return 'Ghi và sử dụng âm thanh thu từ micrô của thiết bị.';
			case 'addons.enhancement.open_stash.label': return 'Mở Kho tạm';
			case 'addons.enhancement.open_stash.description': return 'Xem và quản lý văn bản đã lưu trong Kho tạm.';
			case 'addons.enhancement.pop_from_stash.label': return 'Lấy từ Kho tạm';
			case 'addons.enhancement.pop_from_stash.description': return 'Nhanh chóng lấy mục mới nhất trong Kho tạm.';
			case 'addons.enhancement.text_segmentation.label': return 'Tách văn bản';
			case 'addons.enhancement.text_segmentation.description': return 'Tìm kiếm hoặc chọn một mục từ mới trong văn bản đã được tách.';
			case 'addons.enhancement.bing_images_search.label': return 'Tìm hình ảnh trên Bing';
			case 'addons.enhancement.bing_images_search.description': return 'Tìm hình ảnh trên Bing bằng truy vấn hình ảnh hiện tại hoặc từ hiện tại.';
			case 'addons.enhancement.crop_image.label': return 'Cắt hình ảnh';
			case 'addons.enhancement.crop_image.description': return 'Cắt hình ảnh hiện được chọn.';
			case 'addons.enhancement.pick_image.label': return 'Chọn hình ảnh';
			case 'addons.enhancement.pick_image.description': return 'Chọn hình ảnh mới bằng trình chọn bên ngoài.';
			case 'addons.enhancement.camera.label': return 'Máy ảnh';
			case 'addons.enhancement.camera.description': return 'Chụp ảnh mới để dùng làm hình ảnh.';
			case 'addons.enhancement.sentence_picker.label': return 'Chọn câu';
			case 'addons.enhancement.sentence_picker.description': return 'Chọn các câu được phân cách bằng dấu câu và khoảng trắng.';
			case 'addons.enhancement.search_dictionary.label': return 'Tra từ điển';
			case 'addons.enhancement.search_dictionary.description': return 'Tìm trong từ điển bằng nội dung của một trường.';
			case 'addons.enhancement.massif_example_sentences.label': return 'Câu ví dụ từ Massif';
			case 'addons.enhancement.massif_example_sentences.description': return 'Lấy các câu ví dụ được tuyển chọn qua Massif.';
			case 'addons.enhancement.tatoeba_example_sentences.label': return 'Câu ví dụ từ Tatoeba';
			case 'addons.enhancement.tatoeba_example_sentences.description': return 'Chọn cụm từ và câu ví dụ từ Tatoeba.';
			case 'addons.enhancement.immersion_kit.label': return 'ImmersionKit';
			case 'addons.enhancement.immersion_kit.description': return 'Lấy các câu ví dụ kèm hình ảnh và âm thanh.';
			case 'addons.enhancement.save_tags.label': return 'Lưu nhãn';
			case 'addons.enhancement.save_tags.description': return 'Lưu văn bản hiện tại vào trường Nhãn.';
			case 'addons.action.card_creator.label': return 'Trình tạo thẻ';
			case 'addons.action.card_creator.description': return 'Tạo thẻ từ mục từ điển đã chọn và chỉnh sửa trước khi xuất.';
			case 'addons.action.instant_export.label': return 'Xuất ngay';
			case 'addons.action.instant_export.description': return 'Xuất thẻ ngay từ mục từ điển đã chọn.';
			case 'addons.action.add_to_stash.label': return 'Thêm vào Kho tạm';
			case 'addons.action.add_to_stash.description': return 'Nhanh chóng lưu từ đầu mục của một mục từ điển vào Kho tạm.';
			case 'addons.action.my_words.label': return 'Mục từ của tôi';
			case 'addons.action.my_words.description': return 'Viết nghĩa riêng của bạn cho một mục từ. Nghĩa này luôn hiển thị đầu tiên mỗi khi bạn tra mục từ.';
			case 'addons.action.copy_to_clipboard.label': return 'Sao chép vào bộ nhớ tạm';
			case 'addons.action.copy_to_clipboard.description': return 'Sao chép từ đầu mục của một mục từ điển vào bộ nhớ tạm.';
			case 'addons.action.share.label': return 'Chia sẻ';
			case 'addons.action.share.description': return 'Chia sẻ thông tin của một mục từ điển.';
			case 'addons.action.play_audio.label': return 'Phát âm thanh';
			case 'addons.action.play_audio.description': return 'Thử phát âm thanh bằng các tiện ích bổ trợ của trường Âm thanh. Tiện ích tự động được ưu tiên trước.';
			case 'addons.source.player_local_media.label': return 'Phương tiện trên thiết bị';
			case 'addons.source.player_local_media.description': return 'Phát video từ bộ nhớ trên thiết bị.';
			case 'addons.source.player_youtube.label': return 'YouTube';
			case 'addons.source.player_youtube.description': return 'Tìm kiếm và xem video từ YouTube.';
			case 'addons.source.player_network_stream.label': return 'Luồng mạng';
			case 'addons.source.player_network_stream.description': return 'Phát trực tuyến video từ URL trực tiếp.';
			case 'addons.source.reader_ttu.label': return 'ッツ Ebook Reader';
			case 'addons.source.reader_ttu.description': return 'Đọc EPUB và tạo thẻ từ câu qua trình đọc web tích hợp.';
			case 'addons.source.reader_mokuro.label': return 'Mokuro';
			case 'addons.source.reader_mokuro.description': return 'Đọc các tập manga đã được xử lý thành một tệp HTML duy nhất bằng Mokuro.';
			case 'addons.source.reader_browser.label': return 'Trình duyệt';
			case 'addons.source.reader_browser.description': return 'Duyệt trang web bằng trình duyệt cho phép tìm kiếm và tạo thẻ từ văn bản đã chọn.';
			case 'addons.source.reader_lyrics.label': return 'Lời bài hát';
			case 'addons.source.reader_lyrics.description': return 'Cho phép lấy và tô sáng lời bài hát của phương tiện đang phát, được lấy từ Google và Uta-Net.';
			case 'addons.source.reader_chatgpt.label': return 'ChatGPT';
			case 'addons.source.reader_chatgpt.description': return 'Cho phép người dùng tương tác với mô hình ngôn ngữ AI bằng khóa API chính thức từ OpenAI.';
			case 'addons.source.reader_clipboard.label': return 'Bộ nhớ tạm';
			case 'addons.source.reader_clipboard.description': return 'Cho phép hiển thị văn bản được dán từ bộ nhớ tạm dưới dạng văn bản có thể chọn.';
			case 'addons.source.reader_websocket.label': return 'WebSocket';
			case 'addons.source.reader_websocket.description': return 'Chọn văn bản nhận được từ máy chủ WebSocket và tạo thẻ từ đó.';
			case 'addons.source.viewer_camera.label': return 'Máy ảnh';
			case 'addons.source.viewer_camera.description': return 'Xem hình ảnh được chụp bằng máy ảnh hoặc được chọn từ phương tiện.';
			default: return null;
		}
	}
}
