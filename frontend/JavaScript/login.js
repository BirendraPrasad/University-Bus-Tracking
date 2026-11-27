document.addEventListener("DOMContentLoaded", function () {

    const API_BASE = window.API_BASE_URL;
    const LOGIN_URL = `${API_BASE}/auth/login`;

    // =========================
    // ROLE → DASHBOARD
    // =========================

    const rolePages = {
        STUDENT: "common dashboard.html",
        DRIVER: "driver dashboard.html",
        FACULTY: "common dashboard.html",
        ADMIN: "admin dashboard.html"
    };


    // =========================
    // ELEMENTS
    // =========================

    const form = document.getElementById("loginForm");
    const emailInput = document.getElementById("email");
    const passwordInput = document.getElementById("password");
    const routeIdInput = document.getElementById("routeId");
    const routeIdField = document.getElementById("routeIdField");

    const togglePassword =
        document.getElementById("togglePassword");

    const rememberMe =
        document.getElementById("rememberMe");

    const forgotLink =
        document.getElementById("forgotLink");

    const loginBtn =
        document.getElementById("loginBtn");

    const btnText =
        loginBtn.querySelector(".btn-text");

    const formMessage =
        document.getElementById("formMessage");


    // =========================
    // CHECK ELEMENTS
    // =========================

    if (!form || !emailInput || !passwordInput || !loginBtn) {

        console.error("Login page elements are missing.");

        return;
    }


    // =========================
    // YEAR
    // =========================

    const brandYear =
        document.getElementById("brandYear");

    if (brandYear) {
        brandYear.textContent =
            new Date().getFullYear();
    }


    // =========================
    // MESSAGE
    // =========================

    function showMessage(message, type) {

        formMessage.textContent = message;

        formMessage.className =
            "form-message is-visible " + type;

        formMessage.hidden = false;
    }


    function clearMessage() {

        formMessage.textContent = "";

        formMessage.className =
            "form-message";

        formMessage.hidden = true;
    }


    // =========================
    // SHOW / HIDE PASSWORD
    // =========================

    if (togglePassword) {

        togglePassword.addEventListener("click", function () {

            if (passwordInput.type === "password") {

                passwordInput.type = "text";

                const text =
                    togglePassword.querySelector(".tp-text");

                if (text) {
                    text.textContent = "Hide";
                }

                togglePassword.setAttribute(
                    "aria-label",
                    "Hide password"
                );

            } else {

                passwordInput.type = "password";

                const text =
                    togglePassword.querySelector(".tp-text");

                if (text) {
                    text.textContent = "Show";
                }

                togglePassword.setAttribute(
                    "aria-label",
                    "Show password"
                );
            }

        });
    }


    // =========================
    // FORGOT PASSWORD
    // =========================

    if (forgotLink) {

        forgotLink.addEventListener("click", function () {

            showMessage(
                "Password recovery will be available soon.",
                "info"
            );

        });
    }


    // =========================
    // LOGIN
    // =========================

    form.addEventListener("submit", async function (event) {

        // VERY IMPORTANT
        // Prevent email/password from appearing in URL
        event.preventDefault();

        clearMessage();


        const email =
            emailInput.value.trim();

        const password =
            passwordInput.value;

        const routeIdValue =
            routeIdInput ? routeIdInput.value.trim() : "";

        const routeId =
            routeIdValue === "" ? null : Number(routeIdValue);


        // =========================
        // VALIDATION
        // =========================

        if (!email || !password) {

            showMessage(
                "Please enter both email and password.",
                "error"
            );

            return;
        }


        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {

            showMessage(
                "Please enter a valid email address.",
                "error"
            );

            return;
        }

        if (routeIdField && !routeIdField.hidden && (!routeIdInput.value.trim() || Number(routeIdInput.value) < 1)) {
            showMessage(
                "Please enter your assigned Route ID.",
                "error"
            );
            routeIdInput.focus();
            return;
        }


        // =========================
        // LOADING
        // =========================

        loginBtn.disabled = true;

        btnText.textContent =
            "Logging in...";


        try {

            // =========================
            // FASTAPI LOGIN
            // =========================

            const response = await fetch(
                LOGIN_URL,
                {
                    method: "POST",

                    headers: {
                        "Content-Type": "application/json"
                    },

                    body: JSON.stringify({
                        email: email,
                        password: password,
                        route_id: routeId
                    })
                }
            );


            const data =
                await response.json();


            // =========================
            // ERROR
            // =========================

            if (!response.ok) {

                if (
                    response.status === 400 &&
                    data.detail === "Route ID is required for driver login"
                ) {
                    if (routeIdField) {
                        routeIdField.hidden = false;
                    }
                    showMessage(
                        "Driver account detected. Please enter your assigned Route ID to continue.",
                        "info"
                    );

                    // Reset button so the user can submit Route ID
                    loginBtn.disabled = false;
                    btnText.textContent = "Login";

                    if (routeIdInput) routeIdInput.focus();
                    return;
                }

                if (response.status === 401) {

                    throw new Error(
                        "Invalid email or password"
                    );
                }

                if (response.status === 403) {
                    throw new Error(
                        data.detail || "User account is inactive"
                    );
                }

                throw new Error(
                    data.detail ||
                    "Login failed. Please try again."
                );
            }


            // =========================
            // CHECK TOKEN
            // =========================

            if (!data.access_token) {

                throw new Error(
                    "Unexpected server response."
                );
            }


            // =========================
            // SAVE LOGIN DATA
            // =========================

            const storage =
                rememberMe && rememberMe.checked
                    ? localStorage
                    : sessionStorage;


            storage.setItem(
                "access_token",
                data.access_token
            );

            storage.setItem(
                "token_type",
                data.token_type || "bearer"
            );

            storage.setItem(
                "user_id",
                String(data.user_id)
            );

            storage.setItem(
                "user_name",
                data.name || ""
            );

            storage.setItem(
                "user_email",
                data.email || ""
            );

            storage.setItem(
                "user_role",
                data.role || ""
            );


            // =========================
            // SUCCESS
            // =========================

            showMessage(
                "✓ Login successful! Redirecting...",
                "success"
            );

            btnText.textContent =
                "Login Successful ✓";


            // =========================
            // ROLE REDIRECT
            // =========================

            const role =
                (data.role || "").toUpperCase();

            const target =
                rolePages[role];

            console.log("LOGIN DATA:", data);
            console.log("ROLE:", role);
            console.log("TARGET:", target);    


            if (!target) {

                showMessage(
                    "Login successful, but dashboard is not configured.",
                    "info"
                );

                loginBtn.disabled = false;

                btnText.textContent =
                    "Login";

                return;
            }


            setTimeout(function () {

                window.location.href =
                    target;

            }, 1200);


        } catch (error) {

            console.error(
                "Login request failed:",
                error
            );


            showMessage(
                "✕ " + error.message,
                "error"
            );


            loginBtn.disabled = false;

            btnText.textContent =
                "Login";
        }

    });

});