import json
import os
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
citas_table = dynamodb.Table(os.environ.get('TABLA_CITAS'))

def lambda_handler(event, context):
    """
    Reserva de Cita con Bloqueo Atómico (Anti-Cruce).
    Si dos acudientes intentan reservar la misma fecha/hora para el mismo profesor,
    la condición 'attribute_not_exists(FechaHora)' rechaza atómicamente al segundo.
    """
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
    }
    
    try:
        body = json.loads(event.get('body', '{}'))
        profesor_id = body.get('profesor_id')
        fecha_hora = body.get('fecha_hora') # Formato ISO8601: "2026-11-25T10:00:00Z"
        acudiente_nombre = body.get('acudiente_nombre')
        acudiente_telefono = body.get('acudiente_telefono')
        alumno_nombre = body.get('alumno_nombre')
        motivo = body.get('motivo', 'Reunión de seguimiento académico')

        if not profesor_id or not fecha_hora or not acudiente_nombre or not acudiente_telefono:
            return {
                "statusCode": 400,
                "headers": headers,
                "body": json.dumps({"error": "Faltan campos obligatorios para agendar la cita."})
            }

        item = {
            "ProfesorID": profesor_id,
            "FechaHora": fecha_hora,
            "AcudienteNombre": acudiente_nombre,
            "AcudienteTelefono": acudiente_telefono,
            "AlumnoNombre": alumno_nombre,
            "Motivo": motivo,
            "Estado": "CONFIRMADA",
            "CreatedAt": context.aws_request_id
        }

        # ESCRITURA CONDICIONAL ATÓMICA:
        # Falla con ConditionalCheckFailedException si ya existe un registro con la misma clave compuesta.
        citas_table.put_item(
            Item=item,
            ConditionExpression="attribute_not_exists(FechaHora)"
        )

        return {
            "statusCode": 201,
            "headers": headers,
            "body": json.dumps({
                "mensaje": "¡Cita reservada con éxito!",
                "detalle": {
                    "profesor_id": profesor_id,
                    "fecha_hora": fecha_hora,
                    "alumno": alumno_nombre
                }
            })
        }

    except ClientError as e:
        if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
            # COLISIÓN EVITADA
            return {
                "statusCode": 409, # Conflict
                "headers": headers,
                "body": json.dumps({
                    "error": "HORARIO_OCUPADO",
                    "mensaje": "Lo sentimos, este horario acaba de ser reservado por otro acudiente. Por favor elija otra hora."
                })
            }
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": f"Error en base de datos: {str(e)}"})
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": f"Error inesperado: {str(e)}"})
        }
