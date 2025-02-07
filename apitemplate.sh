#!/bin/bash

# Ask for project directory name
echo "✏️ Enter the name for your WebAPI project: ✏️"
read directoryName

# Create new WebAPI project
dotnet new webapi -o "$directoryName"

# Change into project directory
cd "$directoryName"

# Initialize git and create gitignore
dotnet new gitignore
git init

# Create the new launchSettings.json content
launchSettings='{
  "$schema": "http://json.schemastore.org/launchsettings.json",
  "iisSettings": {
    "windowsAuthentication": false,
    "anonymousAuthentication": true,
    "iisExpress": {
      "applicationUrl": "http://localhost:2550",
      "sslPort": 44332
    }
  },
  "profiles": {
    "https": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "launchUrl": "swagger",
      "applicationUrl": "https://localhost:5001;http://localhost:5000",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    },
    "IIS Express": {
      "commandName": "IISExpress",
      "launchBrowser": true,
      "launchUrl": "swagger",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  }
}'

# Replace the launchSettings.json file
echo "$launchSettings" > "./Properties/launchSettings.json"

# Install required packages
echo "Installing required packages..."
dotnet add package Microsoft.AspNetCore.Identity.EntityFrameworkCore -v 8.0
dotnet add package Microsoft.EntityFrameworkCore.Design -v 8.0
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL -v 8.0

# Create the new Program.cs content with replaced project name
cat << EOF > Program.cs
using System;
using System.Text.Json.Serialization;
using ${directoryName}.Data;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers()
    .AddJsonOptions(opts =>
    {
        opts.JsonSerializerOptions.ReferenceHandler = ReferenceHandler.IgnoreCycles;
    });

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Configure Authentication and Identity
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(CookieAuthenticationDefaults.AuthenticationScheme, options =>
    {
        options.Cookie.Name = "${directoryName}LoginCookie";
        options.Cookie.SameSite = SameSiteMode.Strict;
        options.Cookie.HttpOnly = true; // The cookie cannot be accessed through JS (protects against XSS)
        options.Cookie.MaxAge = TimeSpan.FromDays(7); // Cookie expires in a week regardless of activity
        options.SlidingExpiration = true; // Extend the cookie lifetime with activity up to 7 days.
        options.ExpireTimeSpan = TimeSpan.FromHours(24); // Cookie expires in 24 hours without activity
        options.Events.OnRedirectToLogin = context =>
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            return Task.CompletedTask;
        };
        options.Events.OnRedirectToAccessDenied = context =>
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            return Task.CompletedTask;
        };
    });

builder.Services.AddIdentityCore<IdentityUser>(config =>
    {
        config.Password.RequireDigit = false;
        config.Password.RequiredLength = 8;
        config.Password.RequireLowercase = false;
        config.Password.RequireNonAlphanumeric = false;
        config.Password.RequireUppercase = false;
        config.User.RequireUniqueEmail = true;
    })
    .AddRoles<IdentityRole>()
    .AddEntityFrameworkStores<${directoryName}DbContext>();

// Allows passing DateTimes without time zone data
AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);

// Configure Database Connection

var connectionString = builder.Configuration["${directoryName}DbConnectionString"];

if (string.IsNullOrEmpty(connectionString))
{
    throw new Exception("Database connection string is missing! Check user-secrets.");
}

builder.Services.AddDbContext<${directoryName}DbContext>(options => options.UseNpgsql(connectionString));

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

// Middleware for Authentication and Authorization
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
EOF

# Create Data directory
mkdir -p Data

# Create DbContext file content
dbContext="using ${directoryName}.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
namespace ${directoryName}.Data;
public class ${directoryName}DbContext : IdentityDbContext<IdentityUser>
{
    private readonly IConfiguration _configuration;
    
    public DbSet<UserProfile> UserProfiles { get; set; }
    public ${directoryName}DbContext(
        DbContextOptions<${directoryName}DbContext> context,
        IConfiguration config
    )
        : base(context)
    {
        _configuration = config;
    }
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder
            .Entity<IdentityRole>()
            .HasData(
                new IdentityRole
                {
                    Id = \"c3aaeb97-d2ba-4a53-a521-4eea61e59b35\",
                    Name = \"Admin\",
                    NormalizedName = \"admin\",
                }
            );
        modelBuilder
            .Entity<IdentityUser>()
            .HasData(
                new IdentityUser
                {
                    Id = \"dbc40bc6-0829-4ac5-a3ed-180f5e916a5f\",
                    UserName = \"Administrator\",
                    Email = \"admin@example.com\",
                    PasswordHash = new PasswordHasher<IdentityUser>().HashPassword(
                        null,
                        _configuration[\"AdminPassword\"]
                    ),
                }
            );
        modelBuilder
            .Entity<IdentityUserRole<string>>()
            .HasData(
                new IdentityUserRole<string>
                {
                    RoleId = \"c3aaeb97-d2ba-4a53-a521-4eea61e59b35\",
                    UserId = \"dbc40bc6-0829-4ac5-a3ed-180f5e916a5f\",
                }
            );
        modelBuilder
            .Entity<UserProfile>()
            .HasData(
                new UserProfile
                {
                    Id = 1,
                    IdentityUserId = \"dbc40bc6-0829-4ac5-a3ed-180f5e916a5f\",
                    FirstName = \"Admina\",
                    LastName = \"Strator\",
                    Address = \"101 Main Street\",
                }
            );
    }
}"

# Write DbContext file
echo "$dbContext" > "./Data/${directoryName}DbContext.cs"

# Ensure Models directory exists
mkdir -p Models

# Create UserProfile.cs file content
userProfileCs="using Microsoft.AspNetCore.Identity;

namespace ${directoryName}.Models;

public class UserProfile
{
    public int Id { get; set; }
    public string FirstName { get; set; }
    public string LastName { get; set; }
    public string Address { get; set; }

    public string IdentityUserId { get; set; }

    public IdentityUser IdentityUser { get; set; }
}"

# Write UserProfile.cs file
echo "$userProfileCs" > "./Models/UserProfile.cs"

echo "UserProfile model created successfully!"

# Ensure DTOs directory exists
mkdir -p DTOs

# Create RegistrationDTO.cs file content
registrationDtoCs="namespace ${directoryName}.Models.DTOs;

public class RegistrationDTO
{
    public string Email { get; set; }
    public string Password { get; set; }
    public string UserName { get; set; }
    public string FirstName { get; set; }
    public string LastName { get; set; }
    public string Address { get; set; }
}"

# Write RegistrationDTO.cs file
echo "$registrationDtoCs" > "./DTOs/RegistrationDTO.cs"

# Create UserProfileDTO.cs file content
userProfileDtoCs="using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Identity;

namespace ${directoryName}.Models.DTOs;

public class UserProfileDTO
{
    public int Id { get; set; }
    public string FirstName { get; set; }
    public string LastName { get; set; }
    public string Address { get; set; }
    public string Email { get; set; }
    public string UserName { get; set; }
    public List<string> Roles { get; set; }
    public string IdentityUserId { get; set; }
    public IdentityUser IdentityUser { get; set; }
}"

# Write UserProfileDTO.cs file
echo "$userProfileDtoCs" > "./DTOs/UserProfileDTO.cs"

echo "DTOs created successfully!"

# Ensure Controllers directory exists
mkdir -p Controllers

# Create AuthController.cs file content
authControllerCs="using System.Security.Claims;
using System.Text;
using ${directoryName}.Data;
using ${directoryName}.Models;
using ${directoryName}.Models.DTOs;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;

namespace ${directoryName}.Controllers;

[ApiController]
[Route(\"api/[controller]\")]
public class AuthController : ControllerBase
{
    private ${directoryName}DbContext _dbContext;
    private UserManager<IdentityUser> _userManager;

    public AuthController(${directoryName}DbContext context, UserManager<IdentityUser> userManager)
    {
        _dbContext = context;
        _userManager = userManager;
    }

    [HttpPost(\"login\")]
    public IActionResult Login([FromHeader(Name = \"Authorization\")] string authHeader)
    {
        try
        {
            string encodedCreds = authHeader.Substring(6).Trim();
            string creds = Encoding
                .GetEncoding(\"iso-8859-1\")
                .GetString(Convert.FromBase64String(encodedCreds));

            int separator = creds.IndexOf(':');
            string email = creds.Substring(0, separator);
            string password = creds.Substring(separator + 1);

            var user = _dbContext.Users.Where(u => u.Email == email).FirstOrDefault();
            var userRoles = _dbContext.UserRoles.Where(ur => ur.UserId == user.Id).ToList();
            var hasher = new PasswordHasher<IdentityUser>();
            var result = hasher.VerifyHashedPassword(user, user.PasswordHash, password);
            if (user != null && result == PasswordVerificationResult.Success)
            {
                var claims = new List<Claim>
                {
                    new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                    new Claim(ClaimTypes.Name, user.UserName.ToString()),
                    new Claim(ClaimTypes.Email, user.Email),
                };

                foreach (var userRole in userRoles)
                {
                    var role = _dbContext.Roles.FirstOrDefault(r => r.Id == userRole.RoleId);
                    claims.Add(new Claim(ClaimTypes.Role, role.Name));
                }

                var claimsIdentity = new ClaimsIdentity(
                    claims,
                    CookieAuthenticationDefaults.AuthenticationScheme
                );

                HttpContext
                    .SignInAsync(
                        CookieAuthenticationDefaults.AuthenticationScheme,
                        new ClaimsPrincipal(claimsIdentity)
                    )
                    .Wait();

                return Ok();
            }

            return new UnauthorizedResult();
        }
        catch (Exception ex)
        {
            return StatusCode(500);
        }
    }

    [HttpGet]
    [Route(\"logout\")]
    [Authorize(AuthenticationSchemes = CookieAuthenticationDefaults.AuthenticationScheme)]
    public IActionResult Logout()
    {
        try
        {
            HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme).Wait();
            return Ok();
        }
        catch (Exception ex)
        {
            return StatusCode(500);
        }
    }

    [HttpGet(\"Me\")]
    [Authorize]
    public IActionResult Me()
    {
        var identityUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        var profile = _dbContext.UserProfiles.SingleOrDefault(up =>
            up.IdentityUserId == identityUserId
        );
        var roles = User.FindAll(ClaimTypes.Role).Select(r => r.Value).ToList();
        if (profile != null)
        {
            var userDto = new UserProfileDTO
            {
                Id = profile.Id,
                FirstName = profile.FirstName,
                LastName = profile.LastName,
                Address = profile.Address,
                IdentityUserId = identityUserId,
                UserName = User.FindFirstValue(ClaimTypes.Name),
                Email = User.FindFirstValue(ClaimTypes.Email),
                Roles = roles,
            };

            return Ok(userDto);
        }
        return NotFound();
    }

    [HttpPost(\"register\")]
    public async Task<IActionResult> Register(RegistrationDTO registration)
    {
        var user = new IdentityUser
        {
            UserName = registration.UserName,
            Email = registration.Email,
        };

        var password = Encoding
            .GetEncoding(\"iso-8859-1\")
            .GetString(Convert.FromBase64String(registration.Password));

        var result = await _userManager.CreateAsync(user, password);
        if (result.Succeeded)
        {
            _dbContext.UserProfiles.Add(
                new UserProfile
                {
                    FirstName = registration.FirstName,
                    LastName = registration.LastName,
                    Address = registration.Address,
                    IdentityUserId = user.Id,
                }
            );
            _dbContext.SaveChanges();

            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(ClaimTypes.Name, user.UserName.ToString()),
                new Claim(ClaimTypes.Email, user.Email),
            };
            var claimsIdentity = new ClaimsIdentity(
                claims,
                CookieAuthenticationDefaults.AuthenticationScheme
            );

            HttpContext
                .SignInAsync(
                    CookieAuthenticationDefaults.AuthenticationScheme,
                    new ClaimsPrincipal(claimsIdentity)
                )
                .Wait();

            return Ok();
        }
        return StatusCode(500);
    }
}"

# Write AuthController.cs file
echo "$authControllerCs" > "./Controllers/AuthController.cs"
echo "AuthController created successfully!"

# Ensure user secrets are initialized
dotnet user-secrets init

# Ask the user for their PostgreSQL password
clear
echo "🔑 Enter your PostgreSQL password: ✏️"
read -s userPassword

# Set the database connection string as a user secret
dotnet user-secrets set ${directoryName}DbConnectionString 'Host=localhost;Port=5432;Username=postgres;Password='"$userPassword"';Database='"$directoryName"''

# Clear stored password from memory
unset userPassword

clear
# Ask the user for the default admin password
echo "🔑 Enter the password for the default admin account: ✏️"
read -s adminPassword

# Set the admin password as a user secret
dotnet user-secrets set AdminPassword "${adminPassword}"

# Clear stored password from memory
unset adminPassword

clear
echo "User secrets configured successfully!"


# Create client directory
mkdir -p client
cd client

# Initialize React project using Vite
npm create vite@latest . -- --template react
clear
# Replace vite.config.js with the specified content
cat > vite.config.js <<EOF
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(() => {
  return {
    server: {
      open: true,
      proxy: {
        "/api": {
          target: "https://localhost:5001",
          changeOrigin: true,
          secure: false,
        },
      },
    },
    build: {
      outDir: "build",
    },
    plugins: [react()],
  };
});
EOF

echo "✅ vite.config.js updated successfully!"


# Install react-router-dom
npm install --save react-router-dom

# Install react-bootstrap and bootstrap
npm install react-bootstrap bootstrap

# Install FontAwesome
echo "Installing FontAwesome for React..."

# Install Font Awesome SVG Core
npm i --save @fortawesome/fontawesome-svg-core

# Install Font Awesome Free Icon Packages
npm i --save @fortawesome/free-solid-svg-icons
npm i --save @fortawesome/free-regular-svg-icons
npm i --save @fortawesome/free-brands-svg-icons

# Install Font Awesome React Component
npm i --save @fortawesome/react-fontawesome@latest

echo "FontAwesome installation complete! ✅"


# Ensure src/components and src/managers directories exist
mkdir -p src/components/auth
mkdir -p src/managers

# Create authManager.js
cat > src/managers/authManager.js <<EOF
const _apiUrl = "/api/auth";

export const login = (email, password) => {
  return fetch(_apiUrl + "/login", {
    method: "POST",
    credentials: "same-origin",
    headers: {
      Authorization: \`Basic \${btoa(\`\${email}:\${password}\`)}\`,
    },
  }).then((res) => (res.status !== 200 ? null : tryGetLoggedInUser()));
};

export const logout = () => fetch(_apiUrl + "/logout");

export const tryGetLoggedInUser = () => {
  return fetch(_apiUrl + "/me").then((res) =>
    res.status === 401 ? null : res.json()
  );
};

export const register = (userProfile) => {
  userProfile.password = btoa(userProfile.password);
  return fetch(_apiUrl + "/register", {
    credentials: "same-origin",
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(userProfile),
  }).then(() => tryGetLoggedInUser());
};
EOF

echo "✅ src/managers/authManager.js created successfully!"

# Create AuthorizedRoute.jsx
cat > src/components/auth/AuthorizedRoute.jsx <<EOF
import { Navigate } from "react-router-dom";

export const AuthorizedRoute = ({ children, loggedInUser, roles, all }) => {
  let authed = loggedInUser
    ? roles && roles.length
      ? all
        ? roles.every((r) => loggedInUser.roles.includes(r))
        : roles.some((r) => loggedInUser.roles.includes(r))
      : true
    : false;

  return authed ? children : <Navigate to="/login" />;
};
EOF

echo "✅ src/components/auth/AuthorizedRoute.jsx created!"


# Create Login.jsx file content
cat > src/components/auth/Login.jsx <<EOF
import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { login } from "../../managers/authManager";
import { Button, Form, FormControl, FormGroup, FormLabel, Alert } from "react-bootstrap";

export default function Login({ setLoggedInUser }) {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [failedLogin, setFailedLogin] = useState(false);

  const handleSubmit = (e) => {
    e.preventDefault();
    login(email, password).then((user) => {
      if (!user) {
        setFailedLogin(true);
      } else {
        setLoggedInUser(user);
        navigate("/");
      }
    });
  };

  return (
    <div className="container" style={{ maxWidth: "500px" }}>
      <h3>Login</h3>
      {failedLogin && <Alert variant="danger">Login failed.</Alert>}
      <Form onSubmit={handleSubmit}>
        <FormGroup>
          <FormLabel>Email</FormLabel>
          <FormControl type="text" value={email} onChange={(e) => setEmail(e.target.value)} />
        </FormGroup>
        <FormGroup>
          <FormLabel>Password</FormLabel>
          <FormControl type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
        </FormGroup>
        <Button variant="primary" className="my-2" type="submit">Login</Button>
      </Form>
      <p>Not signed up? Register <Link to="/register">here</Link></p>
    </div>
  );
}
EOF

echo "✅ src/components/auth/Login.jsx created successfully!"

# Create the Register.jsx file with correct formatting
cat > src/components/auth/Register.jsx <<EOF
import { useState } from "react";
import { register } from "../../managers/authManager";
import { Link, useNavigate } from "react-router-dom";
import { Button, Form, Container, Alert } from "react-bootstrap";

export default function Register({ setLoggedInUser }) {
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [userName, setUserName] = useState("");
  const [email, setEmail] = useState("");
  const [address, setAddress] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");

  const [passwordMismatch, setPasswordMismatch] = useState(false);
  const [registrationFailure, setRegistrationFailure] = useState(false);

  const navigate = useNavigate();

  const handleSubmit = (e) => {
    e.preventDefault();

    if (password !== confirmPassword) {
      setPasswordMismatch(true);
    } else {
      const newUser = {
        firstName,
        lastName,
        userName,
        email,
        address,
        password,
      };
      register(newUser).then((user) => {
        if (user) {
          setLoggedInUser(user);
          navigate("/");
        } else {
          setRegistrationFailure(true);
        }
      });
    }
  };

  return (
    <Container className="mt-4" style={{ maxWidth: "500px" }}>
      <h3>Sign Up</h3>
      {registrationFailure && (
        <Alert variant="danger">Registration failed. Please try again.</Alert>
      )}
      <Form onSubmit={handleSubmit}>
        <Form.Group className="mb-3">
          <Form.Label>First Name</Form.Label>
          <Form.Control
            type="text"
            value={firstName}
            onChange={(e) => setFirstName(e.target.value)}
          />
        </Form.Group>

        <Form.Group className="mb-3">
          <Form.Label>Last Name</Form.Label>
          <Form.Control
            type="text"
            value={lastName}
            onChange={(e) => setLastName(e.target.value)}
          />
        </Form.Group>

        <Form.Group className="mb-3">
          <Form.Label>Email</Form.Label>
          <Form.Control
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </Form.Group>

        <Form.Group className="mb-3">
          <Form.Label>User Name</Form.Label>
          <Form.Control
            type="text"
            value={userName}
            onChange={(e) => setUserName(e.target.value)}
          />
        </Form.Group>

        <Form.Group className="mb-3">
          <Form.Label>Address</Form.Label>
          <Form.Control
            type="text"
            value={address}
            onChange={(e) => setAddress(e.target.value)}
          />
        </Form.Group>

        <Form.Group className="mb-3">
          <Form.Label>Password</Form.Label>
          <Form.Control
            type="password"
            isInvalid={passwordMismatch}
            value={password}
            onChange={(e) => {
              setPasswordMismatch(false);
              setPassword(e.target.value);
            }}
          />
        </Form.Group>

        <Form.Group className="mb-3">
          <Form.Label>Confirm Password</Form.Label>
          <Form.Control
            type="password"
            isInvalid={passwordMismatch}
            value={confirmPassword}
            onChange={(e) => {
              setPasswordMismatch(false);
              setConfirmPassword(e.target.value);
            }}
          />
          <Form.Control.Feedback type="invalid">
            Passwords do not match!
          </Form.Control.Feedback>
        </Form.Group>

        <Button variant="primary" type="submit" disabled={passwordMismatch}>
          Register
        </Button>
      </Form>
      <p className="mt-3">
        Already signed up? Log in <Link to="/login">here</Link>.
      </p>
    </Container>
  );
}
EOF

# Confirm file creation
echo "✅ src/components/auth/Register.jsx has been created successfully!"


echo "Auth components and managers created successfully!"

# Fix `main.jsx`
cat > src/main.jsx <<EOF
import React from "react";
import "bootstrap/dist/css/bootstrap.min.css";
import ReactDOM from "react-dom/client";
import "./index.css";
import App from "./App";
import { BrowserRouter } from "react-router-dom";

const root = ReactDOM.createRoot(document.getElementById("root"));
root.render(
  <BrowserRouter>
    <App />
  </BrowserRouter>
);
EOF

echo "✅ src/main.jsx updated!"

# Fix `App.jsx`
cat > src/App.jsx <<EOF
import { useEffect, useState } from "react";
import { tryGetLoggedInUser } from "./managers/authManager";
import { Spinner } from "react-bootstrap";
import ApplicationViews from "./components/ApplicationViews";
import { library } from "@fortawesome/fontawesome-svg-core";
import { fas } from "@fortawesome/free-solid-svg-icons";
library.add(fas);

function App() {
  const [loggedInUser, setLoggedInUser] = useState();

  useEffect(() => {
    tryGetLoggedInUser().then(setLoggedInUser);
  }, []);

  return loggedInUser === undefined ? (
    <Spinner animation="border" role="status" />
  ) : (
    <>
      
      <ApplicationViews loggedInUser={loggedInUser} setLoggedInUser={setLoggedInUser} />
    </>
  );
}

export default App;
EOF

echo "✅ src/App.jsx updated!"

#  `index.css`
cat > src/index.css <<EOF
/* Import the google web fonts you want to use */
@import url("https://fonts.googleapis.com/css2?family=Nunito:wght@300&family=Quicksand&family=Roboto:wght@100&display=swap");

/* FONTS
font-family: "Nunito", sans-serif;
font-family: "Quicksand", sans-serif;
font-family: "Roboto", sans-serif; 
*/

/* COLOR PALETTE Feel Free to change*/
:root {
  --darkest: #000000;
  --less-dark: #444444;
  --accent: #ffa600;
  --lightest: #ffffff;
  --less-light: #cccccc;
}

/* GLOBAL STYLES */
body,
button,
input,
select,
textarea {
  font-family: "Nunito", sans-serif;
}

body {
  background-color: var(--appBackground);
  margin: 0;
}

h1,
h2,
h3,
h4,
h5,
h6 {
  font-family: "Roboto", serif;
}
EOF
echo "✅ src/index.css updated!"

rm -f src/app.css

# Replace eslint.config.js to disable prop validation
cat > eslint.config.js <<EOF
import js from '@eslint/js'
import globals from 'globals'
import react from 'eslint-plugin-react'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'

export default [
  { ignores: ['dist'] },
  {
    files: ['**/*.{js,jsx}'],
    languageOptions: {
      ecmaVersion: 2020,
      globals: globals.browser,
      parserOptions: {
        ecmaVersion: 'latest',
        ecmaFeatures: { jsx: true },
        sourceType: 'module',
      },
    },
    settings: { react: { version: '18.3' } },
    plugins: {
      react,
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
    },
    rules: {
      ...js.configs.recommended.rules,
      ...react.configs.recommended.rules,
      ...react.configs['jsx-runtime'].rules,
      ...reactHooks.configs.recommended.rules,
      // Disable props validation
      'react/prop-types': 'off',
      'react/jsx-no-target-blank': 'off',
      'react-refresh/only-export-components': [
        'warn',
        { allowConstantExport: true },
      ],
    },
  },
]
EOF

echo "✅ eslint.config.js updated to disable prop validation!"


# `ApplicationViews.jsx`
cat > src/components/ApplicationViews.jsx <<EOF
import { Outlet, Route, Routes } from "react-router-dom";
import { AuthorizedRoute } from "./auth/AuthorizedRoute";
import Login from "./auth/Login";
import Register from "./auth/Register";
import NavBar from "./NavBar";

export default function ApplicationViews({ loggedInUser, setLoggedInUser }) {
  return (
    <Routes>
      {/* PARENT ROUTE */}
      <Route
        path="/"
        // This element is your "layout" that wraps children in an <Outlet />
        element={
          //Renders the NavBar above web content
          <>
            <NavBar
              loggedInUser={loggedInUser}
              setLoggedInUser={setLoggedInUser}
            />

            {/* All nested routes will appear here */}
            <Outlet />
          </>
        }
      >
        {/* CHILD ROUTES */}
        {/* Home (index) route */}
        <Route
          index
          element={
            <AuthorizedRoute loggedInUser={loggedInUser}>
              <h1 className="text-center">Welcome</h1>
            </AuthorizedRoute>
          }
        />

        {/* /login route */}
        <Route
          path="login"
          element={<Login setLoggedInUser={setLoggedInUser} />}
        />

        {/* /register route */}
        <Route
          path="register"
          element={<Register setLoggedInUser={setLoggedInUser} />}
        />
      </Route>

      {/* CATCH-ALL ROUTE */}
      <Route path="*" element={<p>Whoops, nothing here...</p>} />
    </Routes>
  );
}



EOF

echo "✅ src/components/ApplicationViews.jsx created!"


# Fix `NavBar.jsx`
cat > src/components/NavBar.jsx <<EOF
import { NavLink } from "react-router-dom";
import { Button, Navbar, Nav } from "react-bootstrap";
import { logout } from "../managers/authManager";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";

export default function NavBar({ loggedInUser, setLoggedInUser }) {
  return (
    <Navbar bg="light" expand="lg">
      <Navbar.Brand as={NavLink} to="/" className="mx-5">
        <FontAwesomeIcon icon="fa-solid fa-home" />
      </Navbar.Brand>
      <Nav className="ms-auto mx-5">
        {loggedInUser ? (
          <Button
            variant="outline-danger"
            onClick={() => logout().then(() => setLoggedInUser(null))}
          >
            Logout
          </Button>
        ) : (
          <Nav.Link as={NavLink} to="/login">
            <Button variant="outline-primary">Login</Button>
          </Nav.Link>
        )}
      </Nav>
    </Navbar>
  );
}


EOF

echo "✅ src/components/NavBar.jsx created!"

# Move back to WebAPI project root
cd ..

# Run EF Migrations and Update Database
dotnet ef migrations add InitialCreate
dotnet ef database update

echo "✅ Migrations and database update complete!"


# This script writes initialsetup.sh and creates a README explaining how to run it.

echo "Creating initialsetup.sh..."

# Get the current directory name
PROJECT_NAME=$(basename "$PWD")

cat << EOF > initialsetup.sh
#!/bin/bash

# Restore .NET dependencies
echo "Restoring .NET dependencies..."
dotnet restore || { echo "Error: dotnet restore failed"; exit 1; }

# Initialize user-secrets
echo "Initializing user-secrets..."
dotnet user-secrets init || { echo "Error: user-secrets initialization failed"; exit 1; }

# Clear screen before prompting for passwords
clear

# Prompt for the database password securely
echo "🔑 Enter your PostgreSQL password: ✏️"
read -s db_password
clear

# Prompt for the admin password securely
echo "🔑 Enter your admin password: ✏️"
read -s admin_password
clear

# Set user-secrets for database connection string
echo "Setting database connection string..."
dotnet user-secrets set \${PROJECT_NAME}DbConnectionString "Host=localhost;Port=5432;Username=postgres;Password=\$db_password;Database=\${PROJECT_NAME}" || { echo "Error: Failed to set database connection string"; exit 1; }

# Set user-secrets for admin password
echo "Setting admin password..."
dotnet user-secrets set AdminPassword "\$admin_password" || { echo "Error: Failed to set admin password"; exit 1; }

# Clear stored password variables
unset db_password
unset admin_password

# Add initial migration
echo "Adding initial migration..."
dotnet ef migrations add InitialCreate || { echo "Error: Failed to add migration"; exit 1; }

# Update database
echo "Updating database..."
dotnet ef database update || { echo "Error: Database update failed"; exit 1; }

# Install frontend dependencies
echo "Installing frontend dependencies..."
cd client && npm install || { echo "Error: npm install failed"; exit 1; }

# Replace eslint.config.js to disable prop validation
cat > client/eslint.config.js <<ENDCONFIG
import js from '@eslint/js'
import globals from 'globals'
import react from 'eslint-plugin-react'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'

export default [
  { ignores: ['dist'] },
  {
    files: ['**/*.{js,jsx}'],
    languageOptions: {
      ecmaVersion: 2020,
      globals: globals.browser,
      parserOptions: {
        ecmaVersion: 'latest',
        ecmaFeatures: { jsx: true },
        sourceType: 'module',
      },
    },
    settings: { react: { version: '18.3' } },
    plugins: {
      react,
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
    },
    rules: {
      ...js.configs.recommended.rules,
      ...react.configs.recommended.rules,
      ...react.configs['jsx-runtime'].rules,
      ...reactHooks.configs.recommended.rules,
      // Disable props validation
      'react/prop-types': 'off',
      'react/jsx-no-target-blank': 'off',
      'react-refresh/only-export-components': [
        'warn',
        { allowConstantExport: true },
      ],
    },
  },
]
ENDCONFIG

echo "✅ eslint.config.js updated to disable prop validation!"

cd ..

# Final message
echo "Setup complete!"
EOF

echo "Creating README file..."
cat << READMEEOF > README.txt
# ${PROJECT_NAME}

## Overview
${PROJECT_NAME} is a web application featuring a .NET WebAPI backend and a React frontend. It includes authentication, PostgreSQL integration, and Bootstrap styling.

### Features
🔧 .NET WebAPI with authentication and PostgreSQL integration.
⚛️ React frontend with Bootstrap and routing.
🚀 One-command setup via a Bash script.
🔄 Entity Framework migrations included.
🔒 User authentication with ASP.NET Identity.

### Tech Stack
- **Backend**: .NET 8, ASP.NET Core WebAPI, EF Core, PostgreSQL
- **Frontend**: React, React-Bootstrap, Vite, React Router
- **Authentication**: ASP.NET Identity with cookie-based auth

## How to Set Up
1. Clone the repository:
2. Navigate into the project directory:
   \`\`\`bash
   cd ${PROJECT_NAME}
   \`\`\`
3. Ensure you have .NET installed.
4. Ensure you have Entity Framework Core installed. If you don't, run:
   \`\`\`bash
   dotnet tool install --global dotnet-ef
   \`\`\`
5. Ensure you have PostgreSQL installed and running. If you haven't already, install PostgreSQL from [postgresql.org](https://www.postgresql.org/download/).
6. Run the setup script:
   \`\`\`bash
   bash initialsetup.sh
   \`\`\`
7. Follow the prompts to enter the PostgreSQL and admin passwords.

## What This Script Does
- Restores .NET dependencies.
- Initializes user-secrets.
- Prompts for database and admin passwords securely.
- Sets up user-secrets for database connection.
- Adds an initial Entity Framework migration.
- Updates the database (creating it if it doesn't already exist).
- Installs frontend dependencies with \`npm install\` in the \`client\` directory.

READMEEOF

echo "README created."


