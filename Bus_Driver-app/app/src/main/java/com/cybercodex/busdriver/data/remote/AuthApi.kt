package com.cybercodex.busdriver.data.remote
import com.cybercodex.busdriver.data.model.LoginRequest
import com.cybercodex.busdriver.data.model.LoginResponse
import com.cybercodex.busdriver.data.model.DriverProfileResponse
import com.cybercodex.busdriver.data.model.DriverRouteResponse
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.POST
interface AuthApi {
    @POST("auth/login")
    suspend fun login(
        @Body request: LoginRequest
    ): Response<LoginResponse>
    @GET("drivers/me")
    suspend fun getMyProfile(
        @Header("Authorization") token: String
    ): Response<DriverProfileResponse>
    @GET("drivers/me/route")
    suspend fun getMyRoute(
        @Header("Authorization") token: String
    ): Response<DriverRouteResponse>
}
