package com.cybercodex.busdriver

import android.annotation.SuppressLint
import android.content.Context
import android.net.Uri
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.webkit.WebViewAssetLoader

import android.webkit.GeolocationPermissions
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import android.Manifest
import android.content.pm.PackageManager
import android.webkit.WebChromeClient
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat

private class DriverAuthBridge(
    initialToken: String
) {
    @Volatile
    var token: String = initialToken

    @JavascriptInterface
    fun getAuthToken(): String = token
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun DriverWebViewScreen(
    accessToken: String,
    onLogout: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = androidx.compose.ui.platform.LocalContext.current

    var pendingGeoCallback by remember {
        mutableStateOf<Pair<String, GeolocationPermissions.Callback>?>(null)
    }

    val locationPermissionLauncher =
        rememberLauncherForActivityResult(
            ActivityResultContracts.RequestMultiplePermissions()
        ) { permissions ->

            val granted =
                permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
                        permissions[Manifest.permission.ACCESS_COARSE_LOCATION] == true

            pendingGeoCallback?.let { (origin, callback) ->
                callback.invoke(origin, granted, false)
            }

            pendingGeoCallback = null
        }

    val assetLoader = remember {
        WebViewAssetLoader.Builder()
            .addPathHandler(
                "/assets/",
                WebViewAssetLoader.AssetsPathHandler(context)
            )
            .build()
    }

    val authBridge = remember {
        DriverAuthBridge(accessToken)
    }

    authBridge.token = accessToken

    val webView = remember {
        WebView(context).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.setGeolocationEnabled(true)

            // Development only: local FastAPI uses HTTP.
            settings.mixedContentMode =
                android.webkit.WebSettings.MIXED_CONTENT_ALWAYS_ALLOW

            addJavascriptInterface(authBridge, "AndroidAuth")

            webViewClient = object : WebViewClient() {

                override fun shouldInterceptRequest(
                    view: WebView?,
                    request: WebResourceRequest?
                ): android.webkit.WebResourceResponse? {
                    return request?.url?.let {
                        assetLoader.shouldInterceptRequest(it)
                    }
                }

                override fun shouldOverrideUrlLoading(
                    view: WebView?,
                    request: WebResourceRequest?
                ): Boolean {
                    val url = request?.url?.toString() ?: return false

                    if (url.endsWith("/login.html") ||
                        url.endsWith("login.html")
                    ) {
                        onLogout()
                        return true
                    }

                    return false
                }
            }

            webChromeClient = object : WebChromeClient() {

                override fun onGeolocationPermissionsShowPrompt(
                    origin: String?,
                    callback: GeolocationPermissions.Callback?
                ) {
                    if (origin == null || callback == null) return

                    val fineGranted = ContextCompat.checkSelfPermission(
                        context,
                        Manifest.permission.ACCESS_FINE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED

                    val coarseGranted = ContextCompat.checkSelfPermission(
                        context,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED

                    if (fineGranted || coarseGranted) {
                        callback.invoke(origin, true, false)
                    } else {
                        pendingGeoCallback = Pair(origin, callback)

                        locationPermissionLauncher.launch(
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION
                            )
                        )
                    }
                }
            }

            loadUrl(
                "https://appassets.androidplatform.net/assets/driver/HTML%20code/driver%20dashboard.html"
            )
        }
    }

    DisposableEffect(webView) {
        onDispose {
            webView.stopLoading()
            webView.destroy()
        }
    }

    AndroidView(
        factory = { webView },
        modifier = modifier
    )
}
