package com.cybercodex.busdriver
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cybercodex.busdriver.data.model.LoginRequest
import com.cybercodex.busdriver.data.model.DriverProfileResponse
import com.cybercodex.busdriver.data.model.DriverRouteResponse
import com.cybercodex.busdriver.data.remote.ApiClient
import com.cybercodex.busdriver.ui.theme.UniversityBusDriverTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import androidx.compose.ui.platform.LocalContext



private val Navy = Color(0xFF102A43)
private val Blue = Color(0xFF1976D2)
private val LightBlue = Color(0xFFEAF3FC)
private val Background = Color(0xFFF4F7FB)
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            UniversityBusDriverTheme {
                DriverLoginScreen()
            }
        }
    }
}



@Composable
fun DriverLoginScreen() {
    val context = LocalContext.current

    val sessionPrefs = remember {
        context.getSharedPreferences("driver_session", android.content.Context.MODE_PRIVATE)
    }

    var routeId by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var showPassword by remember { mutableStateOf(false) }
    var isLoading by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf("") }
    var profile by remember { mutableStateOf<DriverProfileResponse?>(null) }
    var accessToken by remember { mutableStateOf<String?>(null) }
    var isRestoringSession by remember { mutableStateOf(true) }

    val scope = rememberCoroutineScope()

    // Restore and validate the saved login session on app launch.
    LaunchedEffect(Unit) {
        val savedToken = sessionPrefs.getString("access_token", null)

        if (!savedToken.isNullOrBlank()) {
            try {
                val response = withContext(Dispatchers.IO) {
                    ApiClient.authApi.getMyProfile("Bearer $savedToken")
                }

                if (response.isSuccessful) {
                    val savedProfile = response.body()

                    if (savedProfile != null) {
                        accessToken = savedToken
                        profile = savedProfile
                    } else {
                        sessionPrefs.edit().remove("access_token").apply()
                    }
                } else {
                    sessionPrefs.edit().remove("access_token").apply()
                }
            } catch (e: Exception) {
                // Keep the saved token if the backend is temporarily unavailable.
                message = "Unable to verify saved session. Check backend connection."
            }
        }

        isRestoringSession = false
    }

    if (isRestoringSession) {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = Background
        ) {
            Box(contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = Blue)
            }
        }
        return
    }

    if (profile != null && accessToken != null) {
        DriverWebViewScreen(
            accessToken = accessToken!!,
            onLogout = {
                sessionPrefs.edit().remove("access_token").apply()
                profile = null
                accessToken = null
                routeId = ""
                email = ""
                password = ""
                message = ""
            }
        )
        return
    }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = Background
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(Navy, Color(0xFF174A75), Background)
                    )
                )
        ) {
            Column(
                modifier = Modifier
                    
                    .fillMaxSize()
                    .systemBarsPadding()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Box(
                    modifier = Modifier
                        .size(76.dp)
                        .background(Color.White, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Text("🚌", fontSize = 38.sp)
                }
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    "UNIVERSITY BUS TRACKING",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = Color.White,
                    letterSpacing = 1.5.sp
                )
                Text(
                    "DRIVER APPLICATION",
                    fontSize = 10.sp,
                    color = Color(0xFFD6E8FA),
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 2.sp
                )
                Spacer(modifier = Modifier.height(32.dp))
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(24.dp),
                    colors = CardDefaults.cardColors(containerColor = Color.White),
                    elevation = CardDefaults.cardElevation(10.dp)
                ) {
                    Column(modifier = Modifier.padding(24.dp)) {
                        Text(
                            "Welcome Back!",
                            fontSize = 25.sp,
                            fontWeight = FontWeight.Bold,
                            color = Navy
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            "Sign in to access your driver dashboard.",
                            fontSize = 13.sp,
                            color = Color.Gray
                        )
                        Spacer(modifier = Modifier.height(22.dp))
                        Text(
                            "Assigned Route ID",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Navy
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        OutlinedTextField(
                            value = routeId,
                            onValueChange = {
                                if (it.length <= 10 && it.all(Char::isDigit)) {
                                    routeId = it
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                            textStyle = TextStyle(color = Color.Black, fontSize = 15.sp),
                            placeholder = { Text("Enter your Route ID") },
                            singleLine = true,
                            shape = RoundedCornerShape(12.dp),
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Number
                            ),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedTextColor = Color.Black,
                                unfocusedTextColor = Color.Black,
                                cursorColor = Blue,
                                focusedBorderColor = Blue,
                                focusedContainerColor = LightBlue,
                                unfocusedContainerColor = Color.White
                            )
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            "Email Address",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Navy
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        OutlinedTextField(
                            value = email,
                            onValueChange = { email = it },
                            modifier = Modifier.fillMaxWidth(),
                            textStyle = TextStyle(color = Color.Black, fontSize = 15.sp),
                            placeholder = { Text("Enter your registered email") },
                            singleLine = true,
                            shape = RoundedCornerShape(12.dp),
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Email
                            ),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedTextColor = Color.Black,
                                unfocusedTextColor = Color.Black,
                                cursorColor = Blue,
                                focusedBorderColor = Blue,
                                focusedContainerColor = LightBlue,
                                unfocusedContainerColor = Color.White
                            )
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            "Password",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Navy
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        OutlinedTextField(
                            value = password,
                            onValueChange = { password = it },
                            modifier = Modifier.fillMaxWidth(),
                            textStyle = TextStyle(color = Color.Black, fontSize = 15.sp),
                            placeholder = { Text("Enter your password") },
                            singleLine = true,
                            shape = RoundedCornerShape(12.dp),
                            visualTransformation = if (showPassword) {
                                VisualTransformation.None
                            } else {
                                PasswordVisualTransformation()
                            },
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Password
                            ),
                            trailingIcon = {
                                TextButton(onClick = {
                                    showPassword = !showPassword
                                }) {
                                    Text(
                                        if (showPassword) "Hide" else "Show",
                                        color = Blue
                                    )
                                }
                            },
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedTextColor = Color.Black,
                                unfocusedTextColor = Color.Black,
                                cursorColor = Blue,
                                focusedBorderColor = Blue,
                                focusedContainerColor = LightBlue,
                                unfocusedContainerColor = Color.White
                            )
                        )
                        Spacer(modifier = Modifier.height(20.dp))
                        if (message.isNotBlank()) {
                            Text(
                                text = message,
                                color = Color(0xFFB3261E),
                                fontSize = 13.sp,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth()
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                        }
                        Button(
                            onClick = {
                                if (routeId.isBlank() || email.isBlank() || password.isBlank()) {
                                    message = "Please enter Route ID, Email and Password."
                                } else {
                                    val routeNumber = routeId.toIntOrNull()
                                    if (routeNumber == null || routeNumber <= 0) {
                                        message = "Please enter a valid Route ID."
                                    } else {
                                        scope.launch {
                                            isLoading = true
                                            message = ""
                                            try {
                                                val loginResponse = withContext(Dispatchers.IO) {
                                                    ApiClient.authApi.login(
                                                        LoginRequest(
                                                            email = email.trim(),
                                                            password = password,
                                                            route_id = routeNumber
                                                        )
                                                    )
                                                }
                                                if (!loginResponse.isSuccessful) {
                                                    val errorText = loginResponse.errorBody()?.string()
                                                    message = try {
                                                        JSONObject(errorText ?: "")
                                                            .optString("detail", "Login failed.")
                                                    } catch (_: Exception) {
                                                        "Login failed. Please check your details."
                                                    }
                                                } else {
                                                    val loginResult = loginResponse.body()
                                                    if (loginResult == null) {
                                                        message = "Server returned an empty login response."
                                                    } else {
                                                        val profileResponse = withContext(Dispatchers.IO) {
                                                            ApiClient.authApi.getMyProfile(
                                                                "Bearer ${loginResult.access_token}"
                                                            )
                                                        }
                                                        if (profileResponse.isSuccessful) {
                                                            val loadedProfile = profileResponse.body()

                                                            if (loadedProfile != null) {
                                                                sessionPrefs.edit()
                                                                    .putString("access_token", loginResult.access_token)
                                                                    .apply()

                                                                accessToken = loginResult.access_token
                                                                profile = loadedProfile
                                                            } else {
                                                                message = "Profile response was empty."
                                                            }
                                                        }

                                                        else {
                                                            message = "Login successful, but profile loading failed (HTTP ${profileResponse.code()})."
                                                        }
                                                    }
                                                }
                                            } catch (e: Exception) {
                                                message = "Connection failed. Check backend and USB connection."
                                            } finally {
                                                isLoading = false
                                            }
                                        }
                                    }
                                }
                            },
                            enabled = !isLoading,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(54.dp),
                            shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Blue
                            )
                        ) {
                            if (isLoading) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(23.dp),
                                    color = Color.White,
                                    strokeWidth = 2.dp
                                )
                            } else {
                                Text(
                                    "SIGN IN",
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.Bold,
                                    letterSpacing = 1.sp
                                )
                            }
                        }
                        Spacer(modifier = Modifier.height(18.dp))
                        Text(
                            "🔒  Secure Driver Authentication",
                            fontSize = 11.sp,
                            color = Color.Gray,
                            modifier = Modifier.align(Alignment.CenterHorizontally)
                        )
                    }
                }
                Spacer(modifier = Modifier.height(24.dp))
                Text(
                    "REAL-TIME BUS TRACKING SYSTEM",
                    fontSize = 10.sp,
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 1.sp
                )
                Spacer(modifier = Modifier.height(5.dp))
                Text(
                    "Powered by CyberCodex",
                    fontSize = 11.sp,
                    color = Color(0xFFD6E8FA)
                )
                Spacer(modifier = Modifier.height(20.dp))
            }
        }
    }
}
@Composable
fun DriverDashboardScreen(
    profile: DriverProfileResponse,
    accessToken: String,
    onLogout: () -> Unit
) {
    val bus = profile.bus
    var assignedRoute by remember { mutableStateOf<DriverRouteResponse?>(null) }
    var routeLoading by remember { mutableStateOf(true) }
    var routeError by remember { mutableStateOf("") }
    LaunchedEffect(accessToken) {
        routeLoading = true
        routeError = ""
        try {
            val response = withContext(Dispatchers.IO) {
                ApiClient.authApi.getMyRoute("Bearer $accessToken")
            }
            if (response.isSuccessful) {
                assignedRoute = response.body()
                if (assignedRoute == null) {
                    routeError = "Route response is empty."
                }
            } else {
                routeError = "Route loading failed (HTTP ${response.code()})."
            }
        } catch (e: Exception) {
            routeError = "Unable to load assigned route. Check backend connection."
        } finally {
            routeLoading = false
        }
    }
    Surface(
        modifier = Modifier.fillMaxSize(),
        color = Background
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .systemBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(20.dp)
        ) {
            Text(
                "UNIVERSITY BUS TRACKING",
                fontSize = 12.sp,
                color = Blue,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.5.sp
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                "Driver Dashboard",
                fontSize = 27.sp,
                color = Navy,
                fontWeight = FontWeight.ExtraBold
            )
            Spacer(modifier = Modifier.height(20.dp))
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = Navy)
            ) {
                Column(modifier = Modifier.padding(22.dp)) {
                    Text(
                        "WELCOME BACK",
                        color = Color(0xFFD6E8FA),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        profile.name,
                        color = Color.White,
                        fontSize = 25.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(5.dp))
                    Text(
                        profile.email,
                        color = Color(0xFFD6E8FA),
                        fontSize = 13.sp
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        "Driver ID: ${profile.driver_id}",
                        color = Color.White,
                        fontSize = 13.sp
                    )
                }
            }
            Spacer(modifier = Modifier.height(20.dp))
            Text(
                "ASSIGNED BUS DETAILS",
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = Navy
            )
            Spacer(modifier = Modifier.height(12.dp))
            if (bus != null) {
                ProfileInfoCard("Bus Number", bus.bus_number)
                ProfileInfoCard("Bus Type", bus.bus_type)
                ProfileInfoCard("Route ID", bus.route_id?.toString() ?: "Not assigned")
                ProfileInfoCard("Capacity", bus.capacity.toString())
                ProfileInfoCard("Registration Number", bus.registration_number)
            } else {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = Color.White)
                ) {
                    Text(
                        "No bus is currently assigned to your account.",
                        modifier = Modifier.padding(18.dp),
                        color = Color(0xFFB3261E)
                    )
                }
            }

            Spacer(modifier = Modifier.height(20.dp))
            Text("MY ASSIGNED ROUTE", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Navy)
            Spacer(modifier = Modifier.height(12.dp))
            if (routeLoading) {
                CircularProgressIndicator(modifier = Modifier.size(24.dp))
            } else if (routeError.isNotBlank()) {
                ProfileInfoCard("Route Status", routeError)
            } else if (assignedRoute != null) {
                val route = assignedRoute!!
                ProfileInfoCard("Route Name", route.route_name)
                ProfileInfoCard("Route Code", route.route_code ?: "N/A")
                ProfileInfoCard("Start Point", route.start_point ?: "N/A")
                ProfileInfoCard("End Point", route.end_point ?: "N/A")
                Text("ROUTE STOPS (${route.stops.size})", fontWeight = FontWeight.Bold, color = Navy)
                route.stops.sortedBy { it.stop_order }.forEach { stop ->
                    ProfileInfoCard("${stop.stop_order}. ${stop.stop_name}", "Lat: ${stop.latitude}, Long: ${stop.longitude}")
                }
            } else {
                ProfileInfoCard("Route Status", "No assigned route found.")
            }
            Spacer(modifier = Modifier.height(20.dp))
            Text(
                "ACCOUNT DETAILS",
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = Navy
            )
            Spacer(modifier = Modifier.height(12.dp))
            ProfileInfoCard("Role", profile.role)
            ProfileInfoCard("Phone", profile.phone ?: "Not available")
            ProfileInfoCard("License Number", profile.license_number ?: "Not available")
            ProfileInfoCard(
                "Account Status",
                if (profile.is_active) "Active" else "Inactive"
            )
            Spacer(modifier = Modifier.height(24.dp))
            Button(
                onClick = onLogout,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFFB3261E)
                )
            ) {
                Text(
                    "LOGOUT",
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.sp
                )
            }
            Spacer(modifier = Modifier.height(20.dp))
            Text(
                "Powered by CyberCodex",
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center,
                color = Color.Gray,
                fontSize = 12.sp
            )
        }
    }
}
@Composable
fun ProfileInfoCard(label: String, value: String) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 10.dp),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                label,
                fontSize = 12.sp,
                color = Color.Gray
            )
            Spacer(modifier = Modifier.height(5.dp))
            Text(
                value,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = Navy
            )
        }
    }
}
