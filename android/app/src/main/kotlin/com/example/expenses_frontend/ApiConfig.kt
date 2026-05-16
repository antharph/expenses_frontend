package com.example.expenses_frontend

/**
 * REST API paths for the Expenses Laravel backend (Sanctum + Firebase).
 *
 * Full URLs are built as `{API_URL from Flutter .env}` + [API_V1_PREFIX] + endpoint.
 * Human-readable contract: repository `docs/api/authentication.md` (Laravel app).
 */
object ApiConfig {
    const val API_V1_PREFIX: String = "/api/v1"

    object Endpoints {
        const val REGISTER: String = "$API_V1_PREFIX/register"
        const val LOGIN: String = "$API_V1_PREFIX/login"
        const val AUTH_GOOGLE: String = "$API_V1_PREFIX/auth/google"
        const val DASHBOARD: String = "$API_V1_PREFIX/dashboard"
        const val LOGOUT: String = "$API_V1_PREFIX/logout"
        const val EXPENSES: String = "$API_V1_PREFIX/expenses"
        const val CATEGORIES: String = "$API_V1_PREFIX/categories"
    }
}
