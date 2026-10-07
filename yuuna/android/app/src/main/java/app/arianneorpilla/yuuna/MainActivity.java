// Derived from the AnkiDroid API Sample

package app.arianneorpilla.yuuna;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import androidx.annotation.NonNull;
import android.net.Uri;
import android.database.Cursor;
import android.content.UriPermission;
import android.provider.OpenableColumns;
import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import com.ichi2.anki.FlashCardsContract;
import com.ichi2.anki.api.AddContentApi;
import android.content.ContentValues;
import androidx.core.content.FileProvider;
import android.content.ContentResolver;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.OutputStream;

import com.ichi2.anki.api.NoteInfo;
import com.ryanheise.audioservice.AudioServiceActivity;
import android.content.res.Configuration;
import android.content.pm.PackageManager;

public class MainActivity extends AudioServiceActivity {
    private static final String ANKIDROID_CHANNEL = "app.arianneorpilla.yuuna/anki";
    private static final int AD_PERM_REQUEST = 4210;
    private static final String FILES_CHANNEL = "app.arianneorpilla.yuuna/files";
    private static final int CREATE_DOCUMENT_REQUEST = 4211;

    /// Waits for the answer to the AnkiDroid permission request.
    private MethodChannel.Result pendingAnkiPermission;

    /// Waits for the user to choose where a new file is saved.
    private MethodChannel.Result pendingCreateDocument;

    /// The file being picked is to be written again later, so access to it
    /// is kept across restarts.
    private boolean keepCreatedDocument;

    private Activity context;
    private AnkiDroidHelper mAnkiDroid;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        isAppRunning = false;
        
        context = MainActivity.this;
        // Create the example data
        mAnkiDroid = new AnkiDroidHelper(context);
    }
    

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == AD_PERM_REQUEST && pendingAnkiPermission != null) {
            boolean granted = grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED;
            pendingAnkiPermission.success(granted);
            pendingAnkiPermission = null;
        }
    }

    private boolean deckExists(String deck) {
        Long deckId = mAnkiDroid.findDeckIdByName(deck);
        return (deckId != null);
    }

    private boolean modelExists(String model) {
        Long deckId = mAnkiDroid.findModelIdByName(model, 8);
        return (deckId != null);
    }

    private static boolean isAppRunning;

    public static boolean getIsAppRunning() {
        return isAppRunning;
    }

    public void addDefaultModel() {
        final AddContentApi api = new AddContentApi(context);

        long modelId;
        if (modelExists("jidoujisho Kinomoto")) {
            modelId = mAnkiDroid.findModelIdByName("jidoujisho Kinomoto", 17);
        } else {
            modelId = api.addNewCustomModel("jidoujisho Kinomoto",
                new String[] {
                    "Term", 
                    "Reading",
                    "Furigana",
                    "Sentence",
                    "Cloze Before",
                    "Cloze Inside",
                    "Cloze After",
                    "Meaning",
                    "Expanded Meaning",
                    "Collapsed Meaning",
                    "Notes",
                    "Context",
                    "Frequency",
                    "Pitch Accent",
                    "Image",
                    "Term Audio",
                    "Sentence Audio",
                },
                new String[] {
                    "jidoujisho Kinomoto"
                },
                new String[] {
                    "<div id=\"word\">{{Term}}</div>"
                },
                new String[] {
                    "<div id=\"word\">{{#Furigana}}{{furigana:Furigana}}{{/Furigana}}{{^Furigana}}{{Term}}{{/Furigana}}</div>{{#Pitch Accent}}{{Pitch Accent}}{{/Pitch Accent}}\n{{#Image}}<div class=\"image\">{{Image}}</div>{{/Image}}\n{{#Term Audio}}{{Term Audio}}{{/Term Audio}}{{#Sentence Audio}}{{Sentence Audio}}{{/Sentence Audio}}\n<div id=\"sentence\">{{#Cloze Inside}}{{Cloze Before}}<span class=\"cloze\">{{Cloze Inside}}</span>{{Cloze After}}{{/Cloze Inside}}{{^Cloze Inside}}{{Sentence}}{{/Cloze Inside}}</div>\n{{#Meaning}}<p><small>{{Meaning}}</small></p>{{/Meaning}}\n{{#Expanded Meaning}}<p><small>{{Expanded Meaning}}</small></p>{{/Expanded Meaning}}{{#Collapsed Meaning}}<details><summary></summary><p><small>{{Collapsed Meaning}}</small></p></details><br>\n{{/Collapsed Meaning}}"
                },
                ".card {\n  font-family: \"Helvetica Neue\", Arial, sans-serif;\n  font-size: 16px;\n  text-align: center;\n  color: #333333;\n  background-color: #F6F6F6;\n  border-radius: 12px;\n  box-shadow: 0 6px 12px rgba(0, 0, 0, 0.2);\n  padding: 24px;\n  margin: 12px;\n  border: 1px solid #D9D9D9;\n}\n\n#word {\n  font-size: 30px;\n  font-weight: bold;\n  margin-bottom: 16px;\n}\n\n.details-summary {\n  cursor: pointer;\n  font-size: 16px;\n  text-shadow: 1px 1px #ffffff;\n  display: flex;\n  justify-content: space-between;\n  align-items: center;\n  margin-bottom: 16px;\n}\n\n.details-summary:hover {\n  color: #6495ED;\n}\n\n.details-summary:hover .arrow {\n  transform: translateX(4px);\n}\n\n.arrow {\n  fill: #777777;\n  transition: transform 0.2s ease-in-out;\n  margin-right: 8px;\n}\n\n.image img {\n  max-width: 100%;\n  height: 150px;\n  border-radius: 12px;\n  box-shadow: 0 6px 12px rgba(0, 0, 0, 0.2);\n  margin-top: 8px;\n  transition: height 0.2s ease-in-out;\n}\n\n.image:hover img {\n  height: auto;\n}\n\n.furigana {\n  font-size: 22px;\n  font-weight: bold;\n  line-height: 1.4;\n  margin-bottom: 16px;\n  text-shadow: 1px 1px #ffffff;\n}\n\n.meaning {\n  font-size: 18px;\n  line-height: 1.6;\n  margin-bottom: 16px;\n  text-shadow: 1px 1px #ffffff;\n}\n\n.cloze {\n  font-weight: 900\n}\n\n#sentence {\n  font-size: 20px;\n  line-height: 1.6;\n  margin-top: 16px;\n} \n\n.pitch {\n  border-top: solid red 2px;\n  padding-top: 1px;\n}\n\n.pitch_end {\n  border-color: red;\n  border-right: solid red 2px;\n  border-top: solid red 2px;  \n  line-height: 1px;\n  margin-right: 1px;\n  padding-right: 1px;\n  padding-top:1px;\n}",
                    null,
                    null
                    );
        }
    }

    private boolean checkForDuplicates(ArrayList<String> models, String key) {
        final AddContentApi api = new AddContentApi(context);
        for (int i = 0; i < models.size(); i++) {
            String model = models.get(i);
            Long mid = mAnkiDroid.findModelIdByName(model, 1);
            if (mid == null) {
                continue;
            }
            List<NoteInfo> notes = api.findDuplicateNotes(mid, key);
            if (!notes.isEmpty()) {
                return true;
            }
        }

        return false;
    }

    private void addNote(String model, String deck, ArrayList<String> fields, ArrayList<String> tags) {
        final AddContentApi api = new AddContentApi(context);

        long deckId;
        if (deckExists(deck)) {
            deckId = mAnkiDroid.findDeckIdByName(deck);
        } else {
            deckId = api.addNewDeck(deck);
        }

        long modelId = mAnkiDroid.findModelIdByName(model, fields.size());
       
        Set<String> allTags = new HashSet<>(Arrays.asList("Yuuna"));
        allTags.addAll(tags);

        api.addNote(modelId, deckId, fields.toArray(new String[fields.size()]), allTags);

        System.out.println("Added note via flutter_ankidroid_api");
        System.out.println("Model: " + modelId);
        System.out.println("Deck: " + deckId);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), ANKIDROID_CHANNEL)
            .setMethodCallHandler(
                (call, result) -> {
                    final String model = call.argument("model");
                    final String deck = call.argument("deck");
                    final String key = call.argument("key");
                    final ArrayList<String> fields = call.argument("fields"); 
                    final ArrayList<String> tags = call.argument("tags"); 
                    final ArrayList<String> models = call.argument("models"); 

                    final String filename = call.argument("filename");
                    final String preferredName = call.argument("preferredName");
                    final String mimeType = call.argument("mimeType");

                    final AddContentApi api = new AddContentApi(context);

                    switch (call.method) {
                        case "addNote":
                            addNote(model, deck, fields, tags);
                            result.success("Added note");
                            break;
                        case "checkForDuplicates":
                            if (mAnkiDroid.shouldRequestPermission()) {
                                result.success(false);
                                return;
                            } else {
                                new Handler(Looper.getMainLooper()).post(new Runnable() {
                                @Override
                                public void run() {
                                    result.success(checkForDuplicates(models, key));
                                }
                                });
                            }
                            break;
                        case "getDecks":
                            result.success(api.getDeckList());
                            break;
                        case "getModelList":
                            result.success(api.getModelList());
                            break;
                        case "getFieldList":
                            Long mid = mAnkiDroid.findModelIdByName(model, 1);
                            result.success(Arrays.asList(api.getFieldList(mid)));
                            break;
                        case "addDefaultModel":
                            addDefaultModel();
                            break;
                        case "requestAnkidroidPermissions":
                            if (mAnkiDroid.shouldRequestPermission()) {
                                if (pendingAnkiPermission != null) {
                                    pendingAnkiPermission.success(false);
                                }
                                pendingAnkiPermission = result;
                                mAnkiDroid.requestPermission(MainActivity.this, AD_PERM_REQUEST);
                            } else {
                                result.success(true);
                            }
                            break;
                        case "addFileToMedia":
                            System.out.println(filename);
                            System.out.println(preferredName);
                            System.out.println(mimeType);

                            // Workaround from KamWithK
                            // https://github.com/ankidroid/Anki-Android/issues/10335
  
                            File file = new File(filename);

                            Uri file_uri = FileProvider.getUriForFile(context, BuildConfig.APPLICATION_ID + ".provider", file);
                            context.grantUriPermission("com.ichi2.anki", file_uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);

                            ContentValues contentValues = new ContentValues();
                            contentValues.put(FlashCardsContract.AnkiMedia.FILE_URI, file_uri.toString());
                            contentValues.put(FlashCardsContract.AnkiMedia.PREFERRED_NAME, preferredName);

                            ContentResolver contentResolver = context.getContentResolver();
                            Uri returnUri = contentResolver.insert(FlashCardsContract.AnkiMedia.CONTENT_URI, contentValues);

                            result.success(new File(returnUri.getPath()).toString().substring(1));

                            break;
                        default:
                            result.notImplemented();
                    }
                }
            );

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), FILES_CHANNEL)
            .setMethodCallHandler(
                (call, result) -> {
                    switch (call.method) {
                        case "createDocument":
                            // Asks where to save a new file, through the system's own
                            // picker, so no storage permission is needed.
                            if (pendingCreateDocument != null) {
                                pendingCreateDocument.success(null);
                            }
                            pendingCreateDocument = result;
                            keepCreatedDocument = Boolean.TRUE.equals(call.argument("keep"));
                            Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                            intent.addCategory(Intent.CATEGORY_OPENABLE);
                            intent.setType(call.argument("mimeType"));
                            intent.putExtra(Intent.EXTRA_TITLE, (String) call.argument("name"));
                            if (keepCreatedDocument) {
                                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION
                                    | Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                                    | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
                            }
                            try {
                                startActivityForResult(intent, CREATE_DOCUMENT_REQUEST);
                            } catch (Exception e) {
                                pendingCreateDocument = null;
                                result.error("unavailable", e.getMessage(), null);
                            }
                            break;
                        case "copyFileToUri":
                            final String source = call.argument("path");
                            final String target = call.argument("uri");
                            new Thread(() -> {
                                try (InputStream in = new FileInputStream(source);
                                     OutputStream out = openForWriting(Uri.parse(target))) {
                                    byte[] buffer = new byte[1 << 16];
                                    int read;
                                    while ((read = in.read(buffer)) != -1) {
                                        out.write(buffer, 0, read);
                                    }
                                    out.flush();
                                    new Handler(Looper.getMainLooper()).post(() -> result.success(true));
                                } catch (Exception e) {
                                    new Handler(Looper.getMainLooper()).post(
                                        () -> result.error("copy_failed", e.getMessage(), null));
                                }
                            }).start();
                            break;
                        case "uriStatus": {
                            // Whether a kept file can still be written, and its name.
                            Uri uri = Uri.parse((String) call.argument("uri"));
                            boolean writable = false;
                            for (UriPermission permission
                                    : getContentResolver().getPersistedUriPermissions()) {
                                if (permission.getUri().equals(uri) && permission.isWritePermission()) {
                                    writable = true;
                                }
                            }
                            Map<String, Object> status = new HashMap<>();
                            status.put("writable", writable);
                            status.put("name", writable ? displayName(uri) : null);
                            result.success(status);
                            break;
                        }
                        case "releaseUri": {
                            Uri uri = Uri.parse((String) call.argument("uri"));
                            try {
                                getContentResolver().releasePersistableUriPermission(uri,
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                                        | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
                            } catch (Exception e) {
                                // Already gone.
                            }
                            result.success(true);
                            break;
                        }
                        default:
                            result.notImplemented();
                    }
                }
            );
    }

    /// The name a document shows under, where its provider tells.
    private String displayName(Uri uri) {
        try (Cursor cursor = getContentResolver().query(
                uri, new String[] {OpenableColumns.DISPLAY_NAME}, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                return cursor.getString(0);
            }
        } catch (Exception e) {
            // The provider does not say.
        }
        return null;
    }

    /// Opens a picked document for writing, emptying it first where the
    /// provider allows; some, like Google Drive, only accept plain "w".
    private OutputStream openForWriting(Uri uri) throws java.io.FileNotFoundException {
        try {
            return getContentResolver().openOutputStream(uri, "wt");
        } catch (java.io.FileNotFoundException | IllegalArgumentException e) {
            return getContentResolver().openOutputStream(uri, "w");
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == CREATE_DOCUMENT_REQUEST && pendingCreateDocument != null) {
            Uri uri = resultCode == Activity.RESULT_OK && data != null ? data.getData() : null;
            if (uri != null && keepCreatedDocument) {
                boolean kept = false;
                try {
                    getContentResolver().takePersistableUriPermission(uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                            | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
                    kept = true;
                } catch (Exception e) {
                    // This place cannot be written again later.
                }
                Map<String, Object> picked = new HashMap<>();
                picked.put("uri", uri.toString());
                picked.put("kept", kept);
                picked.put("name", displayName(uri));
                pendingCreateDocument.success(picked);
            } else {
                pendingCreateDocument.success(uri == null ? null : uri.toString());
            }
            pendingCreateDocument = null;
            keepCreatedDocument = false;
        }
    }
}
