import json
import os
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
citas_table = dynamodb.Table(os.environ.get('TABLA_CITAS'))
profesores_table = dynamodb.Table(os.environ.get('TABLA_PROFESORES'))

# Horarios base de atención del colegio (bloques de 20 min)
HORARIOS_BASE = [
    "08:00", "08:30", "09:00", "09:30",
    "10:00", "10:30", "11:00", "11:30",
    "14:00", "14:30", "15:00", "15:30"
]

def lambda_handler(event, context):
    """
    GET /disponibilidad/{profesor_id}?fecha=YYYY-MM-DD
    Retorna los horarios ocupados y libres para un profesor en una fecha determinada.
    """
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "GET,OPTIONS"
    }

    try:
        path_params = event.get('pathParameters') or {}
        profesor_id = path_params.get('profesor_id')

        query_params = event.get('queryStringParameters') or {}
        fecha = query_params.get('fecha') # Formato: YYYY-MM-DD

        if not profesor_id:
            return {
                "statusCode": 400,
                "headers": headers,
                "body": json.dumps({"error": "Parámetro 'profesor_id' es obligatorio."})
            }

        # 1. Consultar citas del profesor en DynamoDB
        response = citas_table.query(
            KeyConditionExpression=Key('ProfesorID').eq(profesor_id)
        )
        items = response.get('Items', [])

        # 2. Filtrar citas activas (no canceladas)
        citas_ocupadas = []
        for item in items:
            estado = item.get('Estado')
            fecha_hora = item.get('FechaHora', '')
            
            if estado in ['CONFIRMADA', 'BLOQUEADO']:
                if fecha:
                    if fecha_hora.startswith(fecha):
                        citas_ocupadas.append(fecha_hora)
                else:
                    citas_ocupadas.append(fecha_hora)

        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps({
                "profesor_id": profesor_id,
                "fecha_consultada": fecha,
                "horarios_base": HORARIOS_BASE,
                "horarios_ocupados": citas_ocupadas
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": f"Error interno del servidor: {str(e)}"})
        }
