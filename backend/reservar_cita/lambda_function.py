import json
import os
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
citas_table = dynamodb.Table(os.environ.get('TABLA_CITAS'))

def lambda_handler(event, context):
    """
    POST /reservar
    Crea una cita con bloqueo atómico anti-colisión.
    ConditionExpression="attribute_not_exists(FechaHora)" asegura que
    ninguna dos solicitudes puedan reservar la misma fecha/hora para el mismo profesor.
    """
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "POST,OPTIONS"
    }

    try:
        body = json.loads(event.get('body', '{}'))
        profesor_id = body.get('profesor_id')
        fecha_hora = body.get('fecha_hora') # Formato: YYYY-MM-DDTHH:MM
        acudiente_nombre = body.get('acudiente_nombre')
        acudiente_telefono = body.get('acudiente_telefono')
        alumno_nombre = body.get('alumno_nombre')
        motivo = body.get('motivo', 'Seguimiento académico')

        # Validaciones de entrada
        if not all([profesor_id, fecha_hora, acudiente_nombre, acudiente_telefono, alumno_nombre]):
            return {
                "statusCode": 400,
                "headers": headers,
                "body": json.dumps({
                    "error": "CAMPOS_INCOMPLETOS",
                    "mensaje": "Todos los campos (profesor, fecha_hora, acudiente, telefono, alumno) son requeridos."
                })
            }

        item = {
            "ProfesorID": profesor_id,
            "FechaHora": fecha_hora,
            "AcudienteNombre": acudiente_nombre,
            "AcudienteTelefono": acudiente_telefono,
            "AlumnoNombre": alumno_nombre,
            "Motivo": motivo,
            "Estado": "CONFIRMADA",
            "CitaId": context.aws_request_id,
            "CreatedAt": context.aws_request_id
        }

        # ----------------------------------------------------------------------
        # MECÁNICA ANTI-COLISIÓN (ESCRITURA CONDICIONAL ATÓMICA)
        # ----------------------------------------------------------------------
        citas_table.put_item(
            Item=item,
            ConditionExpression="attribute_not_exists(FechaHora)"
        )

        return {
            "statusCode": 201,
            "headers": headers,
            "body": json.dumps({
                "mensaje": "Cita confirmada exitosamente.",
                "codigo_reserva": context.aws_request_id[:8].upper(),
                "cita": {
                    "profesor_id": profesor_id,
                    "fecha_hora": fecha_hora,
                    "alumno": alumno_nombre,
                    "acudiente": acudiente_nombre
                }
            })
        }

    except ClientError as e:
        # Colisión evitada: otro acudiente reservó el horario milisegundos antes
        if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
            return {
                "statusCode": 409, # 409 Conflict
                "headers": headers,
                "body": json.dumps({
                    "error": "HORARIO_OCUPADO",
                    "mensaje": "Lo sentimos, este horario acaba de ser ocupado por otro acudiente. Por favor seleccione otro horario disponible."
                })
            }
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": f"Error DynamoDB: {str(e)}"})
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": f"Error no controlado: {str(e)}"})
        }
