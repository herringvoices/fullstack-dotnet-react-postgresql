### **GitHub Repository Description**  
**📌 dotnet-react-starter**  

A full-stack **.NET WebAPI + React** starter template that automates project setup with a Bash script. This repo includes:  

✅ **Backend:** ASP.NET Core WebAPI with Identity authentication, PostgreSQL, and Entity Framework Core.  
✅ **Frontend:** React with Vite, React-Bootstrap, React Router, and FontAwesome.  
✅ **Automated Setup:** A single script initializes the backend, frontend, database, and migrations.  

### **Features**  
- 🔧 **.NET WebAPI** with authentication and PostgreSQL integration.  
- ⚛️ **React frontend** with Bootstrap and routing.  
- 🚀 **One-command setup** via a Bash script.  
- 🔄 **Entity Framework migrations** included.  
- 🔒 **User authentication** with ASP.NET Identity.  

### **Setup Instructions**  
1. Clone the repo:  
   ```sh
   git clone https://github.com/yourusername/dotnet-react-starter.git
   cd dotnet-react-starter
   ```
2. Run the setup script:  
   ```sh
   bash <(curl -s https://raw.githubusercontent.com/herringvoices/fullstack-dotnet-react-postgresql/main/apitemplate.sh)
   ```
3. Start the backend:  
   ```sh
   cd YourProjectName
   dotnet run
   ```
4. Start the frontend:  
   ```sh
   cd client
   npm run dev
   ```

### **Tech Stack**  
- **Backend:** .NET 8, ASP.NET Core WebAPI, EF Core, PostgreSQL  
- **Frontend:** React, React-Bootstrap, Vite, React Router  
- **Authentication:** ASP.NET Identity with cookie-based auth  
