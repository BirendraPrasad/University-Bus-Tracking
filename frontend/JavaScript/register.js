/* =========================================================
   Chanakya University
   Real-Time University Bus Tracking System
   register.js

   Connects to existing FastAPI + PostgreSQL backend
   ========================================================= */

(function () {

    "use strict";


    // =====================================================
    // CONFIG
    // =====================================================

    const API_BASE = "http://127.0.0.1:8000";

    /*
       This endpoint will be added to the backend:
       POST /auth/register
    */
    const REGISTER_URL = `${API_BASE}/auth/register`;


    // =====================================================
    // DOM
    // =====================================================

    const form = document.getElementById("registerForm");

    const nameInput =
        document.getElementById("name");

    const emailInput =
        document.getElementById("email");

    const roleInput =
        document.getElementById("role");

    const passwordInput =
        document.getElementById("password");

    const confirmPasswordInput =
        document.getElementById("confirmPassword");

    const termsInput =
        document.getElementById("terms");

    const togglePassword =
        document.getElementById("togglePassword");

    const studentFields =
        document.getElementById("studentFields");

    const facultyFields =
        document.getElementById("facultyFields");

    const registerBtn =
        document.getElementById("registerBtn");

    const registerBtnText =
        document.getElementById("registerBtnText");

    const messageBox =
        document.getElementById("formMessage");

    const year =
        document.getElementById("brandYear");


    // Current year
    if (year) {
        year.textContent = new Date().getFullYear();
    }


    // =====================================================
    // MESSAGE
    // =====================================================

    function showMessage(message, type = "error") {

        messageBox.textContent = message;

        messageBox.className =
            `form-message ${type}`;

    }


    function clearMessage() {

        messageBox.textContent = "";

        messageBox.className =
            "form-message";

    }


    // =====================================================
    // ROLE CHANGE
    // =====================================================

    roleInput.addEventListener(
        "change",
        function () {

            clearMessage();

            const role =
                roleInput.value;


            studentFields.hidden =
                role !== "STUDENT";

            facultyFields.hidden =
                role !== "FACULTY";


            /*
               Driver/Admin accounts should normally
               be created by Admin.
            */

            if (role === "DRIVER") {

                showMessage(
                    "Driver accounts require Admin approval.",
                    "info"
                );

            }


            if (role === "ADMIN") {

                showMessage(
                    "Admin accounts can only be created by an authorized administrator.",
                    "info"
                );

            }

        }
    );


    // =====================================================
    // PASSWORD SHOW / HIDE
    // =====================================================

    togglePassword.addEventListener(
        "click",
        function () {

            const hidden =
                passwordInput.type === "password";


            passwordInput.type =
                hidden ? "text" : "password";


            togglePassword.textContent =
                hidden ? "Hide" : "Show";

        }
    );


    // =====================================================
    // PASSWORD STRENGTH
    // =====================================================

    function validPassword(password) {

        /*
           Minimum:
           8 characters
        */

        return password.length >= 8;

    }


    // =====================================================
    // SUBMIT
    // =====================================================

    form.addEventListener(
        "submit",
        async function (event) {

            event.preventDefault();

            clearMessage();


            const name =
                nameInput.value.trim();

            const email =
                emailInput.value.trim();

            const role =
                roleInput.value;

            const password =
                passwordInput.value;

            const confirmPassword =
                confirmPasswordInput.value;


            // =================================================
            // BASIC VALIDATION
            // =================================================

            if (!name) {

                showMessage(
                    "Please enter your full name."
                );

                nameInput.focus();

                return;
            }


            if (!email) {

                showMessage(
                    "Please enter your email address."
                );

                emailInput.focus();

                return;
            }


            if (
                !/^[^\s@]+@[^\s@]+\.[^\s@]+$/
                .test(email)
            ) {

                showMessage(
                    "Please enter a valid email address."
                );

                emailInput.focus();

                return;
            }


            if (!role) {

                showMessage(
                    "Please select your role."
                );

                roleInput.focus();

                return;
            }


            // =================================================
            // DRIVER / ADMIN RESTRICTION
            // =================================================

            if (role === "DRIVER") {

                showMessage(
                    "Driver accounts must be created or approved by an administrator.",
                    "info"
                );

                return;
            }


            if (role === "ADMIN") {

                showMessage(
                    "Admin accounts cannot be created through public registration.",
                    "info"
                );

                return;
            }


            // =================================================
            // PASSWORD
            // =================================================

            if (!validPassword(password)) {

                showMessage(
                    "Password must contain at least 8 characters."
                );

                passwordInput.focus();

                return;
            }


            if (password !== confirmPassword) {

                showMessage(
                    "Passwords do not match."
                );

                confirmPasswordInput.focus();

                return;
            }


            // =================================================
            // TERMS
            // =================================================

            if (!termsInput.checked) {

                showMessage(
                    "Please accept the terms and conditions."
                );

                return;
            }


            // =================================================
            // EXTRA ROLE DATA
            // =================================================

            const enrollmentNo =
                document.getElementById(
                    "enrollmentNo"
                )?.value.trim();


            const studentDepartment =
                document.getElementById(
                    "studentDepartment"
                )?.value.trim();


            const semester =
                document.getElementById(
                    "semester"
                )?.value;


            const employeeId =
                document.getElementById(
                    "employeeId"
                )?.value.trim();


            const facultyDepartment =
                document.getElementById(
                    "facultyDepartment"
                )?.value.trim();


            if (role === "STUDENT") {

                if (
                    !enrollmentNo ||
                    !studentDepartment ||
                    !semester
                ) {

                    showMessage(
                        "Please complete all student details."
                    );

                    return;
                }

            }


            if (role === "FACULTY") {

                if (
                    !employeeId ||
                    !facultyDepartment
                ) {

                    showMessage(
                        "Please complete all faculty details."
                    );

                    return;
                }

            }


            // =================================================
            // LOADING
            // =================================================

            registerBtn.disabled = true;

            registerBtnText.textContent =
                "Creating Account...";


            // =================================================
            // REQUEST DATA
            // =================================================

            const requestData = {

                name: name,

                email: email,

                password: password,

                role: role

            };


            if (role === "STUDENT") {

                requestData.enrollment_no =
                    enrollmentNo;

                requestData.department =
                    studentDepartment;

                requestData.semester =
                    Number(semester);

            }


            if (role === "FACULTY") {

                requestData.employee_id =
                    employeeId;

                requestData.department =
                    facultyDepartment;

            }


            // =================================================
            // FASTAPI REQUEST
            // =================================================

            try {

                const response =
                    await fetch(
                        REGISTER_URL,
                        {
                            method: "POST",

                            headers: {
                                "Content-Type":
                                    "application/json"
                            },

                            body:
                                JSON.stringify(
                                    requestData
                                )
                        }
                    );


                let data = {};

                try {

                    data =
                        await response.json();

                } catch (_) {

                    data = {};

                }


                // =================================================
                // ERROR
                // =================================================

                if (!response.ok) {

                    if (
                        response.status === 409
                    ) {

                        throw new Error(
                            data.detail ||
                            "An account with this email already exists."
                        );

                    }


                    if (
                        response.status === 400
                    ) {

                        throw new Error(
                            data.detail ||
                            "Invalid registration details."
                        );

                    }


                    throw new Error(
                        data.detail ||
                        "Registration failed. Please try again."
                    );

                }


                // =================================================
                // SUCCESS
                // =================================================

                showMessage(
                    "Account created successfully. Redirecting to login...",
                    "success"
                );


                form.reset();

                studentFields.hidden = true;

                facultyFields.hidden = true;


                setTimeout(
                    function () {

                        window.location.href =
                            "login.html";

                    },
                    1200
                );


            } catch (error) {

                console.error(
                    "Registration error:",
                    error
                );


                if (
                    error instanceof TypeError
                ) {

                    showMessage(
                        "Cannot connect to server. Please make sure FastAPI is running."
                    );

                } else {

                    showMessage(
                        error.message
                    );

                }

            } finally {

                registerBtn.disabled =
                    false;

                registerBtnText.textContent =
                    "Create Account";

            }

        }
    );


    // =====================================================
    // TERMS
    // =====================================================

    document
        .getElementById("termsLink")
        .addEventListener(
            "click",
            function (event) {

                event.preventDefault();

                showMessage(
                    "Please follow the university transportation usage rules.",
                    "info"
                );

            }
        );

})();