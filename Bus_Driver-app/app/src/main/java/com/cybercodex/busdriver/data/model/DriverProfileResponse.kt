package com.cybercodex.busdriver.data.model
data class DriverProfileResponse(
    val user_id: Int,
    val name: String,
    val email: String,
    val role: String,
    val is_active: Boolean,
    val driver_id: Int,
    val license_number: String?,
    val phone: String?,
    val bus: BusProfile?
)
data class BusProfile(
    val bus_id: Int,
    val bus_number: String,
    val bus_type: String,
    val capacity: Int,
    val registration_number: String,
    val front_photo: String?,
    val side_photo: String?,
    val route_id: Int?
)
