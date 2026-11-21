package com.cybercodex.busdriver.data.model

data class DriverRouteResponse(val route_id: Int, val route_name: String, val route_code: String?, val description: String?, val start_point: String?, val end_point: String?, val is_active: Boolean, val stops: List<RouteStop>)

data class RouteStop(val stop_id: Int, val stop_name: String, val latitude: Double, val longitude: Double, val stop_order: Int, val pickup_time: String?, val drop_time: String?)
