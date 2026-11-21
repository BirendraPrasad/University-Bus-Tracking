package com.cybercodex.busdriver.data.model
data class LoginResponse(
    val message: String,
    val access_token: String,
    val token_type: String,
    val user_id: Int,
    val name: String,
    val email: String,
    val role: String
)
