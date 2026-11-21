package com.cybercodex.busdriver.data.model
data class LoginRequest(
    val email: String,
    val password: String,
    val route_id: Int
)
