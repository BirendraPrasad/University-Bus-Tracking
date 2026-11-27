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

    const API_BASE = window.API_BASE_URL;

    /*
       This endpoint will be added to the backend:
       POST /auth/register
    */
    const REGISTER_URL = `${API_BASE}/auth/register`;
    const VERIFY_URL = `${API_BASE}/auth/verify-email`;
    const RESEND_URL = `${API_BASE}/auth/resend-otp`;


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
     
    const driverFields =
        document.getElementById("driverFields");    

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
    
    // =====================================================
    // EMAIL OTP VERIFICATION
    // =====================================================

    function showOtpVerification(email, role, initialMessage = "") {
        form.hidden = true;

        const oldPanel = document.getElementById("otpVerificationPanel");
        if (oldPanel) oldPanel.remove();

        const panel = document.createElement("div");
        panel.id = "otpVerificationPanel";
        panel.className = "form-message info";
        panel.style.padding = "20px";
        panel.style.marginTop = "20px";

        panel.innerHTML = `
            <h3>Verify Your Email</h3>
            <p id="otpInfo"></p>
            <input type="text" id="emailOtp"
                placeholder="Enter 6-digit OTP"
                maxlength="6" inputmode="numeric"
                autocomplete="one-time-code">
            <button type="button" id="verifyOtpBtn">Verify Email</button>
            <button type="button" id="resendOtpBtn">Resend OTP</button>
            <p id="otpMessage" role="status"></p>
        `;

        form.insertAdjacentElement("afterend", panel);

        const otpInput = panel.querySelector("#emailOtp");
        const verifyBtn = panel.querySelector("#verifyOtpBtn");
        const resendBtn = panel.querySelector("#resendOtpBtn");
        const otpMessage = panel.querySelector("#otpMessage");

        panel.querySelector("#otpInfo").textContent =
            initialMessage || `A verification code has been sent to ${email}.`;

        otpInput.addEventListener("input", () => {
            otpInput.value = otpInput.value.replace(/\D/g, "").slice(0, 6);
        });

        verifyBtn.addEventListener("click", async () => {
            const otp = otpInput.value.trim();

            if (!/^[0-9]{6}$/.test(otp)) {
                otpMessage.textContent = "Enter a valid 6-digit OTP.";
                return;
            }

            verifyBtn.disabled = true;
            otpMessage.textContent = "Verifying...";

            try {
                const response = await fetch(VERIFY_URL, {
                    method: "POST",
                    headers: {"Content-Type": "application/json"},
                    body: JSON.stringify({email, otp})
                });

                const data = await response.json();

                if (!response.ok) {
                    throw new Error(data.detail || "OTP verification failed.");
                }

                otpMessage.textContent = data.message;
                otpMessage.className = "success";

                setTimeout(() => {
                    window.location.href = "login.html";
                }, 1800);

            } catch (error) {
                otpMessage.textContent = error.message;
                otpMessage.className = "error";
            } finally {
                verifyBtn.disabled = false;
            }
        });

        resendBtn.addEventListener("click", async () => {
            resendBtn.disabled = true;
            otpMessage.textContent = "Sending new OTP...";

            try {
                const response = await fetch(RESEND_URL, {
                    method: "POST",
                    headers: {"Content-Type": "application/json"},
                    body: JSON.stringify({email})
                });

                const data = await response.json();

                if (!response.ok) {
                    throw new Error(data.detail || "Could not resend OTP.");
                }

                otpMessage.textContent = data.message;

                let seconds = 60;
                resendBtn.textContent = `Wait ${seconds}s`;

                const cooldown = setInterval(() => {
                    seconds--;

                    if (seconds <= 0) {
                        clearInterval(cooldown);
                        resendBtn.disabled = false;
                        resendBtn.textContent = "Resend OTP";
                    } else {
                        resendBtn.textContent = `Wait ${seconds}s`;
                    }
                }, 1000);

            } catch (error) {
                otpMessage.textContent = error.message;
                resendBtn.disabled = false;
                resendBtn.textContent = "Resend OTP";
            }
        });
    }

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
             
            driverFields.hidden =
                role !== "DRIVER";    


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
        return (
            password.length >= 8 &&
            /[A-Z]/.test(password) &&
            /[a-z]/.test(password) &&
            /[0-9]/.test(password) &&
            /[^A-Za-z0-9]/.test(password)
        );
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
                    "Password must contain 8 characters, uppercase, lowercase, number and special character."
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

            const licenseNumber =
                document.getElementById(
                    "driverLicenseNumber"
                )?.value.trim();

            const driverPhone =
                document.getElementById(
                    "driverPhone"
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


            if (role === "DRIVER") {

                if (!licenseNumber || !driverPhone) {
                    showMessage(
                        "Please enter license number and phone number."
                    );
                    return;
                }

                if (!/^[0-9]{10}$/.test(driverPhone)) {
                    showMessage(
                        "Please enter a valid 10-digit phone number."
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


            if (role === "DRIVER") {

                    requestData.license_number =
                        licenseNumber;

                    requestData.phone =
                        driverPhone;
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

                showOtpVerification(
                    email,
                    role,
                    data.message || "Registration successful. Please verify your email."
                );

            }
            catch (error)
            {

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