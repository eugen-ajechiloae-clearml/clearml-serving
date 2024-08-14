#!/bin/bash

# print configuration
echo CLEARML_SERVING_TASK_ID="$CLEARML_SERVING_TASK_ID"
echo CLEARML_INFERENCE_TASK_ID="$CLEARML_INFERENCE_TASK_ID"
echo CLEARML_SERVING_PORT="$CLEARML_SERVING_PORT"
echo CLEARML_USE_GUNICORN="$CLEARML_USE_GUNICORN"
echo CLEARML_EXTRA_PYTHON_PACKAGES="$CLEARML_EXTRA_PYTHON_PACKAGES"
echo CLEARML_SERVING_NUM_PROCESS="$CLEARML_SERVING_NUM_PROCESS"
echo CLEARML_SERVING_POLL_FREQ="$CLEARML_SERVING_POLL_FREQ"
echo CLEARML_DEFAULT_KAFKA_SERVE_URL="$CLEARML_DEFAULT_KAFKA_SERVE_URL"
echo CLEARML_SERVING_RESTART_ON_FAILURE="$CLEARML_SERVING_RESTART_ON_FAILURE"

SERVING_PORT="${CLEARML_SERVING_PORT:-8080}"
GUNICORN_NUM_PROCESS="${CLEARML_SERVING_NUM_PROCESS:-4}"
GUNICORN_SERVING_TIMEOUT="${GUNICORN_SERVING_TIMEOUT:-600}"
GUNICORN_MAX_REQUESTS="${GUNICORN_MAX_REQUESTS:-0}"
UVICORN_SERVE_LOOP="${UVICORN_SERVE_LOOP:-uvloop}"
UVICORN_LOG_LEVEL="${UVICORN_LOG_LEVEL:-warning}"

# set default internal serve endpoint (for request pipelining)
CLEARML_DEFAULT_BASE_SERVE_URL="${CLEARML_DEFAULT_BASE_SERVE_URL:-http://127.0.0.1:$SERVING_PORT/serve}"
CLEARML_DEFAULT_TRITON_GRPC_ADDR="${CLEARML_DEFAULT_TRITON_GRPC_ADDR:-127.0.0.1:8001}"

# print configuration
echo WEB_CONCURRENCY="$WEB_CONCURRENCY"
echo SERVING_PORT="$SERVING_PORT"
echo GUNICORN_NUM_PROCESS="$GUNICORN_NUM_PROCESS"
echo GUNICORN_SERVING_TIMEOUT="$GUNICORN_SERVING_PORT"
echo GUNICORN_MAX_REQUESTS="$GUNICORN_MAX_REQUESTS"
echo GUNICORN_EXTRA_ARGS="$GUNICORN_EXTRA_ARGS"
echo UVICORN_SERVE_LOOP="$UVICORN_SERVE_LOOP"
echo UVICORN_EXTRA_ARGS="$UVICORN_EXTRA_ARGS"
echo UVICORN_LOG_LEVEL="$UVICORN_LOG_LEVEL"
echo CLEARML_DEFAULT_BASE_SERVE_URL="$CLEARML_DEFAULT_BASE_SERVE_URL"
echo CLEARML_DEFAULT_TRITON_GRPC_ADDR="$CLEARML_DEFAULT_TRITON_GRPC_ADDR"

# runtime add extra python packages
if [ ! -z "$CLEARML_EXTRA_PYTHON_PACKAGES" ]
then
      python3 -m pip install $CLEARML_EXTRA_PYTHON_PACKAGES
fi

while : ; do
  echo "[DEBUG] ~~~~~~~~~~~~ Debug changes applied ~~~~~~~~~~~~"
  if [ -z "$CLEARML_USE_GUNICORN" ]
  then
    if [ -z "$CLEARML_SERVING_NUM_PROCESS" ]
    then
      echo "Starting Uvicorn server - single worker"
      PYTHONPATH=$(pwd) python3 -m uvicorn \
          clearml_serving.serving.main:app --log-level $UVICORN_LOG_LEVEL --host 0.0.0.0 --port $SERVING_PORT --loop $UVICORN_SERVE_LOOP \
          $UVICORN_EXTRA_ARGS
    else
      echo "Starting Uvicorn server - multi worker"
      PYTHONPATH=$(pwd) python3 clearml_serving/serving/uvicorn_mp_entrypoint.py \
          clearml_serving.serving.main:app --log-level $UVICORN_LOG_LEVEL --host 0.0.0.0 --port $SERVING_PORT --loop $UVICORN_SERVE_LOOP \
          --workers $CLEARML_SERVING_NUM_PROCESS $UVICORN_EXTRA_ARGS
    fi
  else
    echo "Starting Gunicorn server"
    # start service
    PYTHONPATH=$(pwd) python3 -m gunicorn \
        --preload clearml_serving.serving.main:app \
        --workers $GUNICORN_NUM_PROCESS \
        --worker-class uvicorn.workers.UvicornWorker \
        --max-requests $GUNICORN_MAX_REQUESTS \
        --timeout $GUNICORN_SERVING_TIMEOUT \
        --bind 0.0.0.0:$SERVING_PORT \
        $GUNICORN_EXTRA_ARGS
  fi

  echo "[DEBUG] ~~~~~~~~~~~~ Check if we restart here server ~~~~~~~~~~~~"
  if [ -z "$CLEARML_SERVING_RESTART_ON_FAILURE" ]
  then
    echo "[DEBUG] ~~~~~~~~~~~~ Not restarting ~~~~~~~~~~~~"
    break
  fi
  echo "[DEBUG] ~~~~~~~~~~~~ Restarting server ~~~~~~~~~~~~"
done
