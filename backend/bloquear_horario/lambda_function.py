import json
import os
import boto3

dynamodb = boto3.resource('dynamodb')
citas_table = dynamodb.Table(os.environ.get('TABLA_CITAS'))

def lambda_handler(event, context):
    """
    POST /profesor/bloquear
    Permite al docente bloquear una franja horaria para impedir que acudientes agenden.
    """
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "POST,OPTIONS"
    }

    try:
        claims = event.get('requestContext', {}).get('authorizer', {}).get('jwt', {}).get('claims', {})
        profesor_email = claims.get('email')
        profesor_id = claims.get('sub') or profesor_email

        if not profesor_id:
            return {
                "statusCode": 401,
                "headers": headers,
                "body": json.dumps({"error": "No autorizado."})
            }

        body = json.loads(event.get('body', '{}'))
        fecha_hora = body.get('fecha_hora')
        motivo = body.get('motivo', 'Horario bloqueado por el docente')

        if not fecha_hora:
            return {
                "statusCode": 400,
                "headers": headers,
                "body": json.dumps({"error": "Parámetro 'fecha_hora' es obligatorio."})
            }

        item = {
            "ProfesorID": profesor_id,
            "FechaHora": fecha_hora,
            "AcudienteNombre": "N/A",
            "AcudienteTelefono": "N/A",
            "AlumnoNombre": "N/A",
            "Motivo": motivo,
            "Estado": "BLOQUEADO",
            "CreatedAt": context.aws_request_id
        }

        # Guardar bloqueo en la tabla
        citas_table.put_item(Item=item)

        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps({
                "mensaje": f"Franja {fecha_hora} bloqueada exitosamente.",
                "estado": "BLOQUEADO"
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": str(e)})
        }
