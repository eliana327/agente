import json
import os
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
citas_table = dynamodb.Table(os.environ.get('TABLA_CITAS'))

def lambda_handler(event, context):
    """
    Retorna la agenda privada del profesor autenticado con Cognito.
    API Gateway inyecta la identidad verificada del token JWT en event['requestContext']['authorizer']['jwt']['claims'].
    De esta forma un profesor NUNCA puede consultar las citas de otro docente.
    """
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
    }

    try:
        # Extraer identidad institucional desde el token seguro validado por API Gateway
        claims = event.get('requestContext', {}).get('authorizer', {}).get('jwt', {}).get('claims', {})
        profesor_email = claims.get('email')
        profesor_sub = claims.get('sub') # Identificador único de Cognito

        # Usar el ID o email del profesor para consultar ÚNICAMENTE sus citas
        profesor_id = profesor_email or profesor_sub

        if not profesor_id:
            return {
                "statusCode": 401,
                "headers": headers,
                "body": json.dumps({"error": "No autorizado: No se pudo identificar al profesor desde el token."})
            }

        # Consulta particionada en DynamoDB (Rápida y aislada)
        response = citas_table.query(
            KeyConditionExpression=Key('ProfesorID').eq(profesor_id)
        )

        citas = response.get('Items', [])

        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps({
                "profesor": profesor_id,
                "total_citas": len(citas),
                "citas": citas
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": str(e)})
        }
