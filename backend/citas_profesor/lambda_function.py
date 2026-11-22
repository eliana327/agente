import json
import os
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
citas_table = dynamodb.Table(os.environ.get('TABLA_CITAS'))

def lambda_handler(event, context):
    """
    GET /profesor/citas
    Retorna la lista de citas del docente autenticado.
    El ID del docente se extrae directamente de los claims del JWT de Cognito inyectados por API Gateway.
    Un profesor nunca puede ver las citas de otro docente.
    """
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "GET,OPTIONS"
    }

    try:
        # Extraer identidad institucional desde el Token JWT validado
        claims = event.get('requestContext', {}).get('authorizer', {}).get('jwt', {}).get('claims', {})
        profesor_email = claims.get('email')
        profesor_id = claims.get('sub') or profesor_email

        if not profesor_id:
            return {
                "statusCode": 401,
                "headers": headers,
                "body": json.dumps({"error": "No autorizado: Token JWT no válido o ausente."})
            }

        # Consultar la partición del profesor en DynamoDB
        response = citas_table.query(
            KeyConditionExpression=Key('ProfesorID').eq(profesor_id)
        )
        citas = response.get('Items', [])

        # Ordenar cronológicamente por FechaHora
        citas_ordenadas = sorted(citas, key=lambda x: x.get('FechaHora', ''))

        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps({
                "profesor_id": profesor_id,
                "profesor_email": profesor_email,
                "total_citas": len(citas_ordenadas),
                "citas": citas_ordenadas
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": f"Error al consultar agenda: {str(e)}"})
        }
