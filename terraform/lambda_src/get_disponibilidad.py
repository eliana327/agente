import json
import os
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
citas_table = dynamodb.Table(os.environ.get('TABLA_CITAS'))
profesores_table = dynamodb.Table(os.environ.get('TABLA_PROFESORES'))

def lambda_handler(event, context):
    """
    Retorna los horarios disponibles de un profesor.
    Filtra los bloques ya ocupados en la tabla de citas.
    """
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
    }
    
    path_parameters = event.get('pathParameters') or {}
    profesor_id = path_parameters.get('profesor_id')

    if not profesor_id:
        return {
            "statusCode": 400,
            "headers": headers,
            "body": json.dumps({"error": "Debe especificar el profesor_id en la ruta."})
        }

    try:
        # 1. Consultar citas ya ocupadas para este profesor
        response = citas_table.query(
            KeyConditionExpression=Key('ProfesorID').eq(profesor_id)
        )
        citas_ocupadas = [item['FechaHora'] for item in response.get('Items', []) if item.get('Estado') != 'CANCELADA']

        # 2. Retornar citas ocupadas para que el frontend mobile inhabilite esos botones
        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps({
                "profesor_id": profesor_id,
                "horarios_ocupados": citas_ocupadas
            })
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": str(e)})
        }
