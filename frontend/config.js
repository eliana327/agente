// Configuración de conexión con el Backend de AWS Serverless
// Este archivo puede ser actualizado automáticamente por Terraform o manualmente
window.APP_CONFIG = {
  // URL base de la API HTTP desplegada en Amazon API Gateway
  API_BASE_URL: "https://ejemplo-api.execute-api.us-east-1.amazonaws.com",

  // Datos de autenticación Amazon Cognito
  COGNITO_USER_POOL_ID: "us-east-1_ejemploPool",
  COGNITO_CLIENT_ID: "ejemploClientId123456789",
  AWS_REGION: "us-east-1",

  // Información del Colegio
  SCHOOL_NAME: "Colegio San Martín",
  
  // Lista de Docentes para selección de acudientes
  TEACHERS: [
    { id: "prof_garcia", name: "Prof. Carlos García", subject: "Matemáticas", email: "cgarcia@colegio.edu" },
    { id: "prof_rodriguez", name: "Prof. Elena Rodríguez", subject: "Ciencias Naturales", email: "erodriguez@colegio.edu" },
    { id: "prof_martinez", name: "Prof. Andrés Martínez", subject: "Español y Literatura", email: "amartinez@colegio.edu" },
    { id: "prof_lopez", name: "Prof. Sofía López", subject: "Inglés", email: "slopez@colegio.edu" }
  ]
};
