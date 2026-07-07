package com.loveme.intldating

import android.Manifest
import android.annotation.SuppressLint
import android.app.AlertDialog
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Color
import android.net.ConnectivityManager
import android.net.Uri
import android.provider.Settings
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.provider.MediaStore
import android.view.View
import android.webkit.CookieManager
import android.webkit.GeolocationPermissions
import android.webkit.PermissionRequest
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.firebase.messaging.FirebaseMessaging
import com.startapp.sdk.adsbase.StartAppAd
import com.startapp.sdk.adsbase.StartAppSDK
import android.webkit.JavascriptInterface
import android.content.BroadcastReceiver
import android.os.Looper
import android.view.Gravity
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private lateinit var startAppAd: StartAppAd
    private var isExitAfterAd = false
    private var billingManager: BillingManager? = null

    private var fileUploadCallback: ValueCallback<Array<Uri>>? = null
    private var cameraImageUri: Uri? = null
    private var pendingWebPermissionRequest: android.webkit.PermissionRequest? = null
    private var pendingCallType: String? = null  // "call" or "video_call" — set while waiting for mic permission before a call
    private var noInternetDialog: NoInternetDialog? = null
    private lateinit var networkChangeReceiver: NetworkChangeReceiver
    private var bannerView: View? = null
    private val bannerHandler = Handler(Looper.getMainLooper())
    private val inAppReceiver: BroadcastReceiver by lazy {
        object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val title = intent.getStringExtra("title") ?: return
                val body = intent.getStringExtra("body") ?: ""
                showInAppBanner(title, body)
            }
        }
    }

    // Launcher for gallery / file picker
    private val fileChooserLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (fileUploadCallback == null) return@registerForActivityResult

        var results: Array<Uri>? = null
        try {
            results = WebChromeClient.FileChooserParams.parseResult(result.resultCode, result.data)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        fileUploadCallback?.onReceiveValue(results)
        fileUploadCallback = null
    }

    // Launcher for camera capture
    private val cameraLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (fileUploadCallback == null) return@registerForActivityResult

        val uri = if (result.resultCode == RESULT_OK) cameraImageUri else null
        fileUploadCallback?.onReceiveValue(if (uri != null) arrayOf(uri) else null)
        fileUploadCallback = null
        cameraImageUri = null
    }

    // Register ActivityResultLauncher for permissions
    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val allGranted = permissions.values.all { it }
        val pending = pendingWebPermissionRequest
        val callType = pendingCallType

        if (pending != null) {
            pendingWebPermissionRequest = null
            if (allGranted) {
                pending.grant(pending.resources)
            } else {
                pending.deny()
                val permanentlyDenied = permissions.entries.any { (perm, granted) ->
                    !granted && !shouldShowRequestPermissionRationale(perm)
                }
                if (permanentlyDenied) {
                    AlertDialog.Builder(this)
                        .setTitle("Permissions Required")
                        .setMessage("Camera and microphone access is required for calls. Please enable them in App Settings.")
                        .setPositiveButton("Open Settings") { _, _ ->
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", packageName, null))
                            startActivity(intent)
                        }
                        .setNegativeButton("Cancel", null)
                        .show()
                } else {
                    Toast.makeText(this, "Camera and microphone access is required for calls.", Toast.LENGTH_LONG).show()
                }
            }
        } else if (callType != null) {
            // User just responded to the mic permission prompt triggered by a call button click
            pendingCallType = null
            val audioGranted = ContextCompat.checkSelfPermission(
                this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
            if (audioGranted) {
                // Permission granted — resume the call the user tried to start
                val jsResume = "if(window._loveme_resumeCall) window._loveme_resumeCall('${callType.replace("'", "\\'")}');"
                webView.evaluateJavascript(jsResume, null)
            } else {
                val permanentlyDenied = permissions.entries.any { (perm, granted) ->
                    !granted && !shouldShowRequestPermissionRationale(perm)
                }
                if (permanentlyDenied) {
                    AlertDialog.Builder(this)
                        .setTitle("Microphone Required")
                        .setMessage("Microphone access is required to make calls. Please enable it in App Settings.")
                        .setPositiveButton("Open Settings") { _, _ ->
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", packageName, null))
                            startActivity(intent)
                        }
                        .setNegativeButton("Cancel", null)
                        .show()
                } else {
                    Toast.makeText(this, "Microphone permission is required to make calls.", Toast.LENGTH_LONG).show()
                }
            }
        } else if (!allGranted) {
            Toast.makeText(this, "Permissions are recommended for full feature access.", Toast.LENGTH_SHORT).show()
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Request runtime permissions
        requestRuntimePermissions()

        // Check internet connectivity and show no internet dialog if needed
        if (!NetworkUtil.isInternetAvailable(this)) {
            noInternetDialog = NoInternetDialog(this)
            noInternetDialog?.show()
        }

        // Initialize network change receiver
        networkChangeReceiver = NetworkChangeReceiver { isConnected ->
            if (!isConnected) {
                if (noInternetDialog == null || !noInternetDialog!!.isShowing) {
                    noInternetDialog = NoInternetDialog(this)
                    noInternetDialog?.show()
                }
            } else {
                if (noInternetDialog != null && noInternetDialog!!.isShowing) {
                    noInternetDialog?.dismiss()
                    noInternetDialog = null
                }
            }
        }

        try {
            webView = WebView(this)
            setContentView(webView)

            webView.addJavascriptInterface(AndroidNotifier(), "AndroidNotifier")

            // Initialize Google Play Billing. Results are forwarded into the WebView via JS.
            billingManager = BillingManager(this, object : BillingManager.Listener {
                override fun onBillingEvent(eventName: String, json: String) {
                    runOnUiThread {
                        try {
                            // Pass the JSON string to the web app's global handler if present.
                            val js = "if(window.$eventName){window.$eventName(" +
                                org.json.JSONObject.quote(json) + ");}"
                            webView.evaluateJavascript(js, null)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }
            })
            billingManager?.startConnection()

            // Fetch and store FCM token so the JS bridge can return it immediately
            FirebaseMessaging.getInstance().token.addOnSuccessListener { token ->
                getSharedPreferences("loveme_prefs", Context.MODE_PRIVATE)
                    .edit().putString("fcm_token", token).apply()
            }

            webView.settings.javaScriptEnabled = true
            webView.settings.domStorageEnabled = true
            webView.settings.setSupportMultipleWindows(true)
            webView.settings.loadWithOverviewMode = true
            webView.settings.useWideViewPort = true
            
            // Allow file/content access for uploads
            webView.settings.allowFileAccess = true
            webView.settings.allowContentAccess = true

            // Required for WebRTC audio/video playback in WebView
            webView.settings.mediaPlaybackRequiresUserGesture = false

            // Allow Cookies (Required for some authentications and uploads)
            CookieManager.getInstance().setAcceptCookie(true)
            CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)

            webView.setBackgroundColor(Color.parseColor("#FFF0F5"))
            webView.visibility = View.INVISIBLE

            webView.webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                    if (url != null) view?.loadUrl(url)
                    return true
                }

                override fun onPageFinished(view: WebView?, url: String?) {
                    try {
                        webView.evaluateJavascript(
                            """
                            (function() {
                                let loaders = document.querySelectorAll('[class*="load"], [id*="load"], [class*="splash"], [id*="splash"]');
                                loaders.forEach(el => el.style.display = 'none');
                                document.body.style.background = '#FFF0F5';
                            })();
                            """.trimIndent(),
                            null
                        )
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    webView.visibility = View.VISIBLE

                    // Navigate to deep link if app was opened from a notification tap
                    val deepLink = intent?.getStringExtra("deep_link")
                    if (!deepLink.isNullOrEmpty()) {
                        intent.removeExtra("deep_link")
                        webView.evaluateJavascript(
                            "window.location.hash = '${deepLink.replace("'", "\\'")}';",
                            null
                        )
                    }

                    injectLoginDetector()
                    injectCallDetector()
                    injectCallButtonInterceptor()
                }

                override fun doUpdateVisitedHistory(view: WebView?, url: String?, isReload: Boolean) {
                    super.doUpdateVisitedHistory(view, url, isReload)
                    injectLoginDetector()
                    injectCallDetector()
                    injectCallButtonInterceptor()
                }

                override fun onReceivedError(view: WebView?, errorCode: Int, description: String?, failingUrl: String?) {
                    webView.visibility = View.VISIBLE
                    if (noInternetDialog == null || !noInternetDialog!!.isShowing) {
                        noInternetDialog = NoInternetDialog(this@MainActivity)
                        noInternetDialog?.show()
                    }
                }
            }

            // Provide WebChromeClient for File Uploads and Permissions
            webView.webChromeClient = object : WebChromeClient() {
                
                // Handle file chooser (image/file uploads)
                override fun onShowFileChooser(
                    webView: WebView?,
                    filePathCallback: ValueCallback<Array<Uri>>?,
                    fileChooserParams: FileChooserParams?
                ): Boolean {
                    if (fileUploadCallback != null) {
                        fileUploadCallback?.onReceiveValue(null)
                        fileUploadCallback = null
                    }
                    fileUploadCallback = filePathCallback
                    showPhotoPickerDialog()
                    return true
                }

                // Handle microphone / camera requests from WebRTC inside WebView
                override fun onPermissionRequest(request: PermissionRequest?) {
                    if (request == null) return

                    val neededPermissions = mutableListOf<String>()
                    val resources = request.resources

                    val cameraGranted = ContextCompat.checkSelfPermission(
                        this@MainActivity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
                    val audioGranted = ContextCompat.checkSelfPermission(
                        this@MainActivity, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

                    if (resources.contains(PermissionRequest.RESOURCE_VIDEO_CAPTURE) && !cameraGranted) {
                        neededPermissions.add(Manifest.permission.CAMERA)
                    }
                    if (resources.contains(PermissionRequest.RESOURCE_AUDIO_CAPTURE) && !audioGranted) {
                        neededPermissions.add(Manifest.permission.RECORD_AUDIO)
                    }

                    if (neededPermissions.isNotEmpty()) {
                        // Check if any are permanently denied before launching the dialog
                        val permanentlyDenied = neededPermissions.any {
                            !shouldShowRequestPermissionRationale(it)
                        }
                        if (permanentlyDenied) {
                            request.deny()
                            AlertDialog.Builder(this@MainActivity)
                                .setTitle("Permissions Required")
                                .setMessage("Camera and microphone access is required for calls. Please enable them in App Settings.")
                                .setPositiveButton("Open Settings") { _, _ ->
                                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                        Uri.fromParts("package", packageName, null))
                                    startActivity(intent)
                                }
                                .setNegativeButton("Cancel", null)
                                .show()
                        } else {
                            pendingWebPermissionRequest = request
                            requestPermissionLauncher.launch(neededPermissions.toTypedArray())
                        }
                    } else {
                        // All required permissions already granted — allow immediately
                        request.grant(resources)
                    }
                }

                // Handle Geolocation requests from the website
                override fun onGeolocationPermissionsShowPrompt(origin: String?, callback: GeolocationPermissions.Callback?) {
                    callback?.invoke(origin, true, false)
                }
            }

            webView.loadUrl("https://loveme-app.com")

        } catch (e: Exception) {
            e.printStackTrace()
            // Fallback view if WebView fails
            val textView = TextView(this)
            textView.text = "Loading... Please check your internet connection"
            textView.setTextColor(Color.BLACK)
            textView.setBackgroundColor(Color.parseColor("#FFF0F5"))
            textView.gravity = android.view.Gravity.CENTER
            textView.setPadding(50, 50, 50, 50)
            setContentView(textView)
        }

        try {
            StartAppSDK.initParams(this, "202740625")
                .setReturnAdsEnabled(false)
                .init()
            startAppAd = StartAppAd(this)
            startAppAd.loadAd()

            Handler(mainLooper).postDelayed({
                if (startAppAd.isReady) {
                    startAppAd.showAd()
                }
                startAppAd.loadAd()
            }, 15 * 60 * 1000)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun injectCallDetector() {
        // Fetch hook removed — it always fired on the CALLER's device (they make the POST),
        // causing the caller to get their own incoming-call notification.
        // Callees are notified exclusively via Firebase FCM push. Nothing to inject here.
    }

    private fun injectCallButtonInterceptor() {
        val js = """
            (function() {
                if (window._loveme_btn_hooked) return;
                window._loveme_btn_hooked = true;

                // Selectors that match call / video-call buttons in the message page
                var CALL_BTN_SEL = [
                    '[data-action="call"]',
                    '[data-action="video-call"]',
                    '[data-action="video_call"]',
                    '[aria-label*="call" i]',
                    '[aria-label*="video" i]',
                    '[class*="call-btn"]',
                    '[class*="callBtn"]',
                    '[class*="video-call"]',
                    '[class*="videoCall"]',
                    '[id*="call-btn"]',
                    '[id*="callBtn"]',
                    'button[class*="call"]',
                    'a[class*="call"]'
                ].join(',');

                function isVideoButton(el) {
                    var text = (el.textContent || '').toLowerCase();
                    var cls  = (el.className  || '').toLowerCase();
                    var lbl  = (el.getAttribute('aria-label') || '').toLowerCase();
                    var act  = (el.getAttribute('data-action') || '').toLowerCase();
                    return cls.indexOf('video') !== -1 || lbl.indexOf('video') !== -1 ||
                           act.indexOf('video') !== -1 || text.indexOf('video') !== -1;
                }

                function handleCallClick(e) {
                    var callType = isVideoButton(e.currentTarget) ? 'video_call' : 'call';
                    var allowed = false;
                    try { allowed = window.AndroidNotifier.checkMicPermission(callType); } catch(err) {}
                    if (!allowed) {
                        e.preventDefault();
                        e.stopImmediatePropagation();
                    }
                }

                // Attach listeners to existing buttons
                function attachListeners() {
                    try {
                        document.querySelectorAll(CALL_BTN_SEL).forEach(function(btn) {
                            if (btn._loveme_mic_guarded) return;
                            btn._loveme_mic_guarded = true;
                            btn.addEventListener('click', handleCallClick, true);
                        });
                    } catch(e) {}
                }

                // Re-attach when new buttons are added (SPA navigation)
                var obs = new MutationObserver(function() { attachListeners(); });
                obs.observe(document.body, { childList: true, subtree: true });
                attachListeners();

                // Called by Android after permission is granted to resume the blocked call
                window._loveme_resumeCall = function(callType) {
                    try {
                        var sel = callType === 'video_call'
                            ? '[data-action="video-call"],[data-action="video_call"],[class*="video-call"],[class*="videoCall"]'
                            : '[data-action="call"],[class*="call-btn"],[class*="callBtn"]';
                        var btn = document.querySelector(sel);
                        if (btn) {
                            btn._loveme_mic_guarded = false;
                            btn.click();
                        }
                    } catch(e) {}
                };
            })();
        """.trimIndent()
        try { webView.evaluateJavascript(js, null) } catch (e: Exception) { e.printStackTrace() }
    }

    private fun injectLoginDetector() {
        val js = """
            (function() {
                if (window._loveme_login_hooked) return;
                window._loveme_login_hooked = true;

                var LOGIN_RE = /\/(login|signin|sign-in|register|signup|sign-up|auth\/token|auth\/login)/i;

                function extractName(data) {
                    if (!data) return '';
                    return data.name || data.username || data.display_name ||
                        (data.user && (data.user.name || data.user.username)) ||
                        (data.data && (data.data.name || data.data.username)) || '';
                }

                function notifyWelcome(name) {
                    try { window.AndroidNotifier.showWelcomeNotification(String(name || '')); } catch(e) {}
                }

                // Hook fetch
                var _fetch = window.fetch;
                window.fetch = function(resource, init) {
                    return _fetch.call(this, resource, init).then(function(response) {
                        try {
                            var url = (typeof resource === 'string') ? resource : (resource && resource.url) || '';
                            if (LOGIN_RE.test(url) && response.ok) {
                                response.clone().json().then(function(data) {
                                    notifyWelcome(extractName(data));
                                }).catch(function() { notifyWelcome(''); });
                            }
                        } catch(e) {}
                        return response;
                    });
                };

                // Hook XMLHttpRequest
                var _open = XMLHttpRequest.prototype.open;
                XMLHttpRequest.prototype.open = function(method, url) {
                    this._loveme_url = url;
                    return _open.apply(this, arguments);
                };
                var _send = XMLHttpRequest.prototype.send;
                XMLHttpRequest.prototype.send = function() {
                    var xhr = this;
                    xhr.addEventListener('load', function() {
                        try {
                            if (LOGIN_RE.test(xhr._loveme_url || '') && xhr.status >= 200 && xhr.status < 300) {
                                var data = JSON.parse(xhr.responseText);
                                notifyWelcome(extractName(data));
                            }
                        } catch(e) {
                            if (LOGIN_RE.test(xhr._loveme_url || '') && xhr.status >= 200 && xhr.status < 300) {
                                notifyWelcome('');
                            }
                        }
                    });
                    return _send.apply(this, arguments);
                };
            })();
        """.trimIndent()
        try { webView.evaluateJavascript(js, null) } catch (e: Exception) { e.printStackTrace() }
    }

    private fun showPhotoPickerDialog() {
        val dialog = BottomSheetDialog(this)
        val view = layoutInflater.inflate(R.layout.dialog_photo_picker, null)
        dialog.setContentView(view)

        view.findViewById<LinearLayout>(R.id.optionCamera).setOnClickListener {
            dialog.dismiss()
            launchCamera()
        }

        view.findViewById<LinearLayout>(R.id.optionGallery).setOnClickListener {
            dialog.dismiss()
            launchGallery()
        }

        dialog.setOnCancelListener {
            fileUploadCallback?.onReceiveValue(null)
            fileUploadCallback = null
        }

        dialog.show()
    }

    private fun launchCamera() {
        val uri = createCameraImageUri() ?: run {
            fileUploadCallback?.onReceiveValue(null)
            fileUploadCallback = null
            return
        }
        cameraImageUri = uri
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
            putExtra(MediaStore.EXTRA_OUTPUT, uri)
        }
        try {
            cameraLauncher.launch(intent)
        } catch (e: ActivityNotFoundException) {
            fileUploadCallback?.onReceiveValue(null)
            fileUploadCallback = null
            cameraImageUri = null
        }
    }

    private fun launchGallery() {
        val intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI).apply {
            type = "image/*"
        }
        try {
            fileChooserLauncher.launch(intent)
        } catch (e: ActivityNotFoundException) {
            fileUploadCallback?.onReceiveValue(null)
            fileUploadCallback = null
        }
    }

    private fun createCameraImageUri(): Uri? {
        return try {
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val storageDir = getExternalFilesDir(Environment.DIRECTORY_PICTURES)
            val imageFile = File.createTempFile("PHOTO_${timestamp}_", ".jpg", storageDir)
            FileProvider.getUriForFile(this, "${packageName}.fileprovider", imageFile)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun requestRuntimePermissions() {
        val requiredPermissions = mutableListOf<String>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            requiredPermissions.add(Manifest.permission.CAMERA)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requiredPermissions.add(Manifest.permission.RECORD_AUDIO)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_IMAGES) != PackageManager.PERMISSION_GRANTED) {
                requiredPermissions.add(Manifest.permission.READ_MEDIA_IMAGES)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_VIDEO) != PackageManager.PERMISSION_GRANTED) {
                requiredPermissions.add(Manifest.permission.READ_MEDIA_VIDEO)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                requiredPermissions.add(Manifest.permission.READ_MEDIA_AUDIO)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requiredPermissions.add(Manifest.permission.POST_NOTIFICATIONS)
            }
        } else {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                requiredPermissions.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
        }

        if (requiredPermissions.isNotEmpty()) {
            requestPermissionLauncher.launch(requiredPermissions.toTypedArray())
        }
    }

    private fun showInAppBanner(title: String, body: String) {
        val root = window.decorView.findViewById<FrameLayout>(android.R.id.content)
        bannerView?.let { root.removeView(it) }

        val banner = TextView(this).apply {
            text = "🔔 $title: $body"
            setTextColor(android.graphics.Color.WHITE)
            setBackgroundColor(android.graphics.Color.parseColor("#CC1A1A2E"))
            setPadding(40, 28, 40, 28)
            textSize = 14f
            gravity = Gravity.CENTER_VERTICAL
            elevation = 20f
            translationY = -200f
        }

        val params = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply { gravity = Gravity.TOP }

        root.addView(banner, params)
        bannerView = banner

        banner.animate()
            .translationY(0f)
            .setDuration(300)
            .setInterpolator(DecelerateInterpolator())
            .start()

        bannerHandler.removeCallbacksAndMessages(null)
        bannerHandler.postDelayed({
            banner.animate()
                .translationY(-200f)
                .setDuration(300)
                .withEndAction { root.removeView(banner); bannerView = null }
                .start()
        }, 4000)
    }

    override fun onResume() {
        super.onResume()

        // Register in-app notification banner receiver
        val bannerFilter = IntentFilter("com.loveme.SHOW_BANNER")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(inAppReceiver, bannerFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(inAppReceiver, bannerFilter)
        }

        // Register network change receiver
        val intentFilter = IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            registerReceiver(networkChangeReceiver, intentFilter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(networkChangeReceiver, intentFilter)
        }
        
        if (isExitAfterAd) {
            isExitAfterAd = false
            finish()
        }
    }

    override fun onPause() {
        super.onPause()
        try { unregisterReceiver(inAppReceiver) } catch (e: IllegalArgumentException) {}
        try { unregisterReceiver(networkChangeReceiver) } catch (e: IllegalArgumentException) {}
        // Flush cookies to disk so session survives if Android kills the process
        CookieManager.getInstance().flush()
    }

    override fun onDestroy() {
        billingManager?.endConnection()
        billingManager = null
        super.onDestroy()
    }

    inner class AndroidNotifier {
        @JavascriptInterface
        fun getDeviceToken(): String {
            return getSharedPreferences("loveme_prefs", Context.MODE_PRIVATE)
                .getString("fcm_token", "") ?: ""
        }

        // ---- Google Play Billing bridge ----

        /** True if the Play Billing client is connected and ready to take a purchase. */
        @JavascriptInterface
        fun isBillingReady(): Boolean = billingManager?.isBillingReady() == true

        /**
         * Returns a JSON array of available subscription products with localized prices.
         * Empty array if not loaded yet — the web app should also listen for
         * window._loveme_onProducts(json), which fires when products finish loading.
         */
        @JavascriptInterface
        fun getProducts(): String = billingManager?.getProductsJson() ?: "[]"

        /**
         * Launches the Google Play purchase sheet for the given subscription product id
         * (one of BillingManager.SUBSCRIPTION_PRODUCT_IDS). The result is delivered to
         * window._loveme_onPurchaseResult(json) — never assume success synchronously.
         */
        @JavascriptInterface
        fun purchaseSubscription(productId: String) {
            runOnUiThread {
                billingManager?.launchPurchaseFlow(this@MainActivity, productId)
            }
        }

        /**
         * Re-emits subscriptions the user already owns (reinstall / new device).
         * Each owned subscription arrives via window._loveme_onPurchaseResult with
         * status "restored"; "none" means nothing active.
         */
        @JavascriptInterface
        fun restorePurchases() {
            runOnUiThread {
                billingManager?.queryExistingPurchases()
            }
        }

        @JavascriptInterface
        fun checkMicPermission(callType: String): Boolean {
            val granted = ContextCompat.checkSelfPermission(
                this@MainActivity, Manifest.permission.RECORD_AUDIO
            ) == PackageManager.PERMISSION_GRANTED

            if (!granted) {
                pendingCallType = callType
                runOnUiThread {
                    requestPermissionLauncher.launch(arrayOf(Manifest.permission.RECORD_AUDIO))
                }
            }
            return granted
        }

        @JavascriptInterface
        fun showIncomingCallNotification(callerName: String, callType: String) {
            val openAppIntent = Intent(this@MainActivity, SplashActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("notification_type", callType)
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                this@MainActivity, 2001, openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val acceptIntent = Intent(this@MainActivity, CallAcceptReceiver::class.java).apply {
                putExtra("notification_type", callType)
            }
            val acceptPendingIntent = PendingIntent.getBroadcast(
                this@MainActivity, 2002, acceptIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val declineIntent = Intent(this@MainActivity, CallDeclineReceiver::class.java)
            val declinePendingIntent = PendingIntent.getBroadcast(
                this@MainActivity, 2003, declineIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val ringtoneUri = android.media.RingtoneManager.getDefaultUri(
                android.media.RingtoneManager.TYPE_RINGTONE
            )

            val notification = androidx.core.app.NotificationCompat.Builder(
                this@MainActivity, "loveme_call_channel"
            )
                .setSmallIcon(R.mipmap.ic_launcher)
                .setLargeIcon(android.graphics.BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher))
                .setContentTitle(if (callType == "video_call") "Incoming Video Call 📹" else "Incoming Call 📞")
                .setContentText(callerName)
                .setPriority(androidx.core.app.NotificationCompat.PRIORITY_MAX)
                .setCategory(androidx.core.app.NotificationCompat.CATEGORY_CALL)
                .setSound(ringtoneUri)
                .setVibrate(longArrayOf(0, 1000, 500, 1000, 500, 1000))
                .setContentIntent(openAppPendingIntent)
                .setOngoing(true)
                .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Decline", declinePendingIntent)
                .addAction(android.R.drawable.ic_menu_call, "Accept", acceptPendingIntent)
                .build()

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(2001, notification)
        }

        @JavascriptInterface
        fun showWelcomeNotification(userName: String) {
            val prefs = getSharedPreferences("loveme_prefs", Context.MODE_PRIVATE)
            val alreadyShown = prefs.getBoolean("welcome_shown_$userName", false)
            if (alreadyShown) return

            val intent = Intent(this@MainActivity, SplashActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            val pendingIntent = PendingIntent.getActivity(
                this@MainActivity, 0, intent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )

            val notification = androidx.core.app.NotificationCompat.Builder(
                this@MainActivity, "loveme_default_channel"
            )
                .setSmallIcon(R.mipmap.ic_launcher)
                .setLargeIcon(android.graphics.BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher))
                .setContentTitle("Welcome to LoveMe")
                .setContentText("Thanks for joining${if (userName.isNotEmpty()) ", $userName" else ""}. Notifications are enabled.")
                .setAutoCancel(true)
                .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
                .setVibrate(longArrayOf(0, 250, 250, 250))
                .setContentIntent(pendingIntent)
                .build()

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            manager.notify(1001, notification)

            prefs.edit().putBoolean("welcome_shown_$userName", true).apply()
        }
    }

    override fun onBackPressed() {
        try {
            val currentUrl = webView.url

            if (currentUrl == "https://loveme-app.com/" || currentUrl == "https://loveme-app.com") {

                val dialogView = layoutInflater.inflate(R.layout.exit_dialog, null)

                val dialog = AlertDialog.Builder(this)
                    .setView(dialogView)
                    .setCancelable(false)
                    .create()

                dialog.show()

                val btnYes = dialogView.findViewById<TextView>(R.id.btnYes)
                val btnNo = dialogView.findViewById<TextView>(R.id.btnNo)

                btnYes.setOnClickListener {
                    dialog.dismiss()
                    if (::startAppAd.isInitialized && startAppAd.isReady) {
                        isExitAfterAd = true
                        startAppAd.showAd()
                    } else {
                        finish()
                    }
                }

                btnNo.setOnClickListener {
                    dialog.dismiss()
                }

            } else {
                webView.goBack()
            }
        } catch (e: Exception) {
            super.onBackPressed()
        }
    }
}