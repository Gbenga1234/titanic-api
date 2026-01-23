# Application Instrumentation Guide

How to instrument the Titanic API Flask application with Prometheus metrics, OpenTelemetry tracing, and structured logging.

## 1. Installation

### Add Python Dependencies

```bash
pip install prometheus-client opentelemetry-api opentelemetry-sdk \
  opentelemetry-exporter-otlp opentelemetry-instrumentation-flask \
  opentelemetry-instrumentation-sqlalchemy opentelemetry-instrumentation-requests \
  python-json-logger
```

Or add to `requirements.txt`:

```
prometheus-client==0.19.0
opentelemetry-api==1.20.0
opentelemetry-sdk==1.20.0
opentelemetry-exporter-otlp==1.20.0
opentelemetry-instrumentation-flask==0.41b0
opentelemetry-instrumentation-sqlalchemy==0.41b0
opentelemetry-instrumentation-requests==0.41b0
opentelemetry-instrumentation==0.41b0
opentelemetry-propagators==0.41b0
python-json-logger==2.0.7
```

## 2. Setup Prometheus Metrics

Create `src/metrics.py`:

```python
from prometheus_client import Counter, Histogram, Gauge, CollectorRegistry, REGISTRY
import time

# Create custom registry
metrics_registry = REGISTRY

# Request counter
api_requests_total = Counter(
    'api_requests_total',
    'Total API requests',
    ['endpoint', 'method', 'status'],
    registry=metrics_registry
)

# Response latency histogram
api_response_latency_seconds = Histogram(
    'api_response_latency_seconds',
    'API response latency in seconds',
    ['endpoint', 'method'],
    buckets=(0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 2.0, 5.0),
    registry=metrics_registry
)

# Database connection pool gauge
db_pool_available_connections = Gauge(
    'db_pool_available_connections',
    'Available database connections',
    ['service'],
    registry=metrics_registry
)

db_pool_size = Gauge(
    'db_pool_size',
    'Total database connection pool size',
    ['service'],
    registry=metrics_registry
)

# Database query latency
db_query_latency_seconds = Histogram(
    'db_query_latency_seconds',
    'Database query latency in seconds',
    ['query_type'],
    buckets=(0.001, 0.01, 0.1, 1.0),
    registry=metrics_registry
)

# Exception counter
exceptions_total = Counter(
    'exceptions_total',
    'Total exceptions',
    ['exception_type', 'endpoint'],
    registry=metrics_registry
)

# Active requests gauge
active_requests = Gauge(
    'api_active_requests',
    'Number of active API requests',
    ['endpoint', 'method'],
    registry=metrics_registry
)

# Expose metrics registry for Flask
def register_metrics(app):
    from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
    
    @app.route('/metrics')
    def metrics():
        return generate_latest(metrics_registry), 200, {'Content-Type': CONTENT_TYPE_LATEST}
    
    return app
```

## 3. Setup OpenTelemetry Tracing

Create `src/tracing.py`:

```python
import os
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.wsgi import OpenTelemetryMiddleware
from opentelemetry.propagators.jaeger_propagator import JaegerPropagator
from opentelemetry.propagators.jaeger_thrift_propagator import JaegerThriftPropagator
from opentelemetry.propagators.composite import CompositePropagator
from opentelemetry.propagators.b3_format import B3Format
from opentelemetry.propagators.b3 import B3MultiFormat
from opentelemetry.propagate import set_global_textmap

def setup_tracing(app, service_name="titanic-api"):
    """Configure OpenTelemetry tracing and metrics for Flask app."""
    
    # Resource
    resource = Resource.create({
        SERVICE_NAME: service_name,
        "service.version": os.getenv("SERVICE_VERSION", "1.0"),
        "service.instance.id": os.getenv("POD_NAME", "unknown"),
        "deployment.environment": os.getenv("ENVIRONMENT", "production"),
    })
    
    # Configure trace exporter
    otlp_exporter = OTLPSpanExporter(
        endpoint=os.getenv(
            "OTEL_EXPORTER_OTLP_ENDPOINT",
            "localhost:4317"
        ),
        insecure=os.getenv("OTEL_EXPORTER_OTLP_INSECURE", "true").lower() == "true",
    )
    
    # Configure tracer provider
    tracer_provider = TracerProvider(resource=resource)
    tracer_provider.add_span_processor(
        BatchSpanProcessor(otlp_exporter)
    )
    trace.set_tracer_provider(tracer_provider)
    
    # Configure metrics exporter
    metric_exporter = OTLPMetricExporter(
        endpoint=os.getenv(
            "OTEL_EXPORTER_OTLP_ENDPOINT",
            "localhost:4317"
        ),
        insecure=os.getenv("OTEL_EXPORTER_OTLP_INSECURE", "true").lower() == "true",
    )
    
    # Configure metrics provider
    metric_reader = PeriodicExportingMetricReader(metric_exporter)
    metrics_provider = MeterProvider(
        resource=resource,
        metric_readers=[metric_reader],
    )
    metrics.set_meter_provider(metrics_provider)
    
    # Configure propagators for distributed tracing (W3C Trace Context, B3, Jaeger)
    set_global_textmap(
        CompositePropagator([
            B3MultiFormat(),  # B3 Multi Header
            JaegerPropagator(),  # Jaeger Uber header
        ])
    )
    
    # Instrument Flask
    FlaskInstrumentor().instrument_app(app)
    
    # Instrument SQLAlchemy (after creating db connection)
    # Will be called in app factory after db initialization
    
    # Instrument requests library
    RequestsInstrumentor().instrument()
    
    return app

def instrument_sqlalchemy(engine):
    """Instrument SQLAlchemy engine for tracing."""
    SQLAlchemyInstrumentor().instrument(
        engine=engine,
        service=os.getenv("SERVICE_NAME", "titanic-api"),
    )

def get_tracer(name="titanic-api"):
    """Get global tracer instance."""
    return trace.get_tracer(name)

def get_meter(name="titanic-api"):
    """Get global meter instance."""
    return metrics.get_meter(name)
```

## 4. Setup Structured Logging

Create `src/logging_config.py`:

```python
import logging
import json
import os
import sys
from pythonjsonlogger import jsonlogger
from opentelemetry import trace

class JSONFormatter(jsonlogger.JsonFormatter):
    """Custom JSON formatter that adds trace context."""
    
    def add_fields(self, log_record, record, message_dict):
        super().add_fields(log_record, record, message_dict)
        
        # Add trace context
        span = trace.get_current_span()
        context = span.get_span_context()
        
        log_record['timestamp'] = self.formatTime(record, self.datefmt)
        log_record['level'] = record.levelname
        log_record['service'] = os.getenv('SERVICE_NAME', 'titanic-api')
        log_record['version'] = os.getenv('SERVICE_VERSION', '1.0')
        log_record['trace_id'] = format(context.trace_id, '032x')
        log_record['span_id'] = format(context.span_id, '016x')
        log_record['request_id'] = getattr(record, 'request_id', 'unknown')

def setup_logging(log_level=logging.INFO):
    """Configure structured JSON logging."""
    
    # Console handler with JSON formatter
    console_handler = logging.StreamHandler(sys.stdout)
    formatter = JSONFormatter(
        '%(timestamp)s %(level)s %(service)s %(version)s %(trace_id)s %(span_id)s %(request_id)s %(message)s'
    )
    console_handler.setFormatter(formatter)
    
    # Root logger
    root_logger = logging.getLogger()
    root_logger.addHandler(console_handler)
    root_logger.setLevel(log_level)
    
    # Suppress noisy logs
    logging.getLogger('urllib3').setLevel(logging.WARNING)
    logging.getLogger('werkzeug').setLevel(logging.WARNING)
    logging.getLogger('opentelemetry').setLevel(logging.WARNING)
    
    return root_logger

def get_logger(name):
    """Get logger instance."""
    return logging.getLogger(name)
```

## 5. Integrate into Flask App

Update `src/app.py`:

```python
import os
import logging
from flask import Flask, request, g
import uuid
from opentelemetry import trace

# Import our instrumentation
from src.metrics import register_metrics, api_requests_total, api_response_latency_seconds, active_requests
from src.tracing import setup_tracing, instrument_sqlalchemy
from src.logging_config import setup_logging, get_logger

logger = get_logger(__name__)

def create_app(config_name=None):
    """Flask app factory."""
    
    # Setup logging first
    log_level_str = os.getenv('LOG_LEVEL', 'INFO')
    log_level = getattr(logging, log_level_str.upper(), logging.INFO)
    setup_logging(log_level)
    
    app = Flask(__name__)
    
    # Configure app
    if config_name is None:
        config_name = os.getenv('FLASK_ENV', 'development')
    
    if config_name == 'production':
        from src.config import Production
        app.config.from_object(Production)
    elif config_name == 'testing':
        from src.config import Testing
        app.config.from_object(Testing)
    else:
        from src.config import Development
        app.config.from_object(Development)
    
    # Initialize database
    from src.models import db
    db.init_app(app)
    
    with app.app_context():
        db.create_all()
    
    # Setup tracing and metrics
    setup_tracing(app)
    instrument_sqlalchemy(db.engine)
    register_metrics(app)
    
    # Register request hooks for metrics/tracing
    @app.before_request
    def before_request():
        # Generate request ID
        request.request_id = request.headers.get('X-Request-ID', str(uuid.uuid4())[:8])
        
        # Store request start time
        request.start_time = time.time()
        
        # Add to context for logging
        g.request_id = request.request_id
        
        # Increment active requests
        active_requests.labels(
            endpoint=request.endpoint or 'unknown',
            method=request.method
        ).inc()
        
        logger.info(
            f"{request.method} {request.path} started",
            extra={'request_id': request.request_id}
        )
    
    @app.after_request
    def after_request(response):
        # Calculate request duration
        duration = time.time() - request.start_time
        
        # Record metrics
        endpoint = request.endpoint or 'unknown'
        method = request.method
        status = response.status_code
        
        api_requests_total.labels(
            endpoint=endpoint,
            method=method,
            status=status
        ).inc()
        
        api_response_latency_seconds.labels(
            endpoint=endpoint,
            method=method
        ).observe(duration)
        
        active_requests.labels(
            endpoint=endpoint,
            method=method
        ).dec()
        
        # Log request completion
        logger.info(
            f"{method} {request.path} completed",
            extra={
                'request_id': request.request_id,
                'status': status,
                'duration_ms': int(duration * 1000),
                'endpoint': endpoint,
            }
        )
        
        # Add trace ID to response headers
        span = trace.get_current_span()
        context = span.get_span_context()
        response.headers['X-Trace-ID'] = format(context.trace_id, '032x')
        response.headers['X-Request-ID'] = request.request_id
        
        return response
    
    @app.errorhandler(Exception)
    def handle_exception(error):
        # Record exception metric
        from src.metrics import exceptions_total
        exceptions_total.labels(
            exception_type=type(error).__name__,
            endpoint=request.endpoint or 'unknown'
        ).inc()
        
        # Log exception
        logger.exception(
            f"Exception in {request.method} {request.path}",
            extra={'request_id': request.request_id}
        )
        
        # Return error response
        return {
            'error': str(error),
            'request_id': request.request_id,
            'trace_id': format(trace.get_current_span().get_span_context().trace_id, '032x')
        }, 500
    
    # Register blueprints
    from src.views import people_bp
    app.register_blueprint(people_bp)
    
    # Health check endpoints
    @app.route('/health/live')
    def health_live():
        return {'status': 'alive'}, 200
    
    @app.route('/health/ready')
    def health_ready():
        try:
            # Check database connectivity
            db.session.execute('SELECT 1')
            return {'status': 'ready'}, 200
        except Exception as e:
            logger.error(f"Readiness check failed: {e}")
            return {'status': 'not ready', 'error': str(e)}, 503
    
    logger.info(f"Flask app created (environment: {config_name})")
    
    return app
```

## 6. Add Instrumentation to Views

Update `src/views/people.py`:

```python
from flask import Blueprint, request, jsonify, g
import logging
from opentelemetry import trace
from src.metrics import api_requests_total, api_response_latency_seconds
from src.models import Person, person_schema, persons_schema

logger = logging.getLogger(__name__)
people_bp = Blueprint('people', __name__, url_prefix='/people')
tracer = trace.get_tracer(__name__)

@people_bp.route('', methods=['GET'])
def get_all_people():
    """Get all people."""
    with tracer.start_as_current_span("get_all_people") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.url", request.url)
        
        try:
            people = Person.get_all()
            
            logger.info(
                "Retrieved all people",
                extra={
                    'request_id': g.request_id,
                    'count': len(people),
                }
            )
            
            return persons_schema.dump(people), 200
        
        except Exception as e:
            logger.error(
                f"Failed to get people: {str(e)}",
                extra={'request_id': g.request_id}
            )
            span.record_exception(e)
            span.set_attribute("error", True)
            raise

@people_bp.route('/<id>', methods=['GET'])
def get_person(id):
    """Get a person by ID."""
    with tracer.start_as_current_span("get_person") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("person.id", id)
        
        try:
            person = Person.get_by_id(id)
            
            if not person:
                logger.warning(
                    f"Person not found: {id}",
                    extra={'request_id': g.request_id}
                )
                span.add_event("person_not_found")
                return {'error': 'Person not found'}, 404
            
            logger.info(
                f"Retrieved person {id}",
                extra={'request_id': g.request_id}
            )
            
            return person_schema.dump(person), 200
        
        except Exception as e:
            logger.error(
                f"Failed to get person {id}: {str(e)}",
                extra={'request_id': g.request_id}
            )
            span.record_exception(e)
            span.set_attribute("error", True)
            raise

@people_bp.route('', methods=['POST'])
def create_person():
    """Create a new person."""
    with tracer.start_as_current_span("create_person") as span:
        span.set_attribute("http.method", "POST")
        
        try:
            data = request.get_json()
            
            logger.info(
                "Creating new person",
                extra={
                    'request_id': g.request_id,
                    'data_keys': list(data.keys()),
                }
            )
            
            person = person_schema.load(data)
            person.save()
            
            logger.info(
                f"Created person {person.id}",
                extra={'request_id': g.request_id}
            )
            
            return person_schema.dump(person), 201
        
        except Exception as e:
            logger.error(
                f"Failed to create person: {str(e)}",
                extra={'request_id': g.request_id}
            )
            span.record_exception(e)
            span.set_attribute("error", True)
            raise
```

## 7. Environment Variables

Set these in your Kubernetes deployment:

```yaml
env:
  # Application
  - name: SERVICE_NAME
    value: "titanic-api"
  - name: SERVICE_VERSION
    value: "1.0"
  - name: ENVIRONMENT
    value: "production"
  - name: LOG_LEVEL
    value: "INFO"
  - name: LOG_FORMAT
    value: "json"
  
  # OpenTelemetry
  - name: OTEL_SDK_DISABLED
    value: "false"
  - name: OTEL_EXPORTER_OTLP_PROTOCOL
    value: "grpc"
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://otel-collector.monitoring.svc.cluster.local:4317"
  - name: OTEL_EXPORTER_OTLP_TIMEOUT
    value: "10"
  - name: OTEL_TRACES_EXPORTER
    value: "otlp"
  - name: OTEL_METRICS_EXPORTER
    value: "otlp"
  - name: OTEL_PROPAGATORS
    value: "tracecontext,baggage"
  - name: OTEL_TRACES_SAMPLER
    value: "parentbased_traceidratio"
  - name: OTEL_TRACES_SAMPLER_ARG
    value: "0.1"
  
  # Pod metadata
  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: POD_NAMESPACE
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
```

## 8. Testing Instrumentation

```python
# test_instrumentation.py
import pytest
from src.app import create_app
from src.metrics import api_requests_total

@pytest.fixture
def client():
    app = create_app('testing')
    with app.test_client() as client:
        yield client

def test_metrics_endpoint(client):
    """Test that /metrics endpoint works."""
    response = client.get('/metrics')
    assert response.status_code == 200
    assert b'api_requests_total' in response.data

def test_request_metrics(client):
    """Test that requests increment metrics."""
    client.get('/health/live')
    
    response = client.get('/metrics')
    assert b'api_requests_total{' in response.data

def test_tracing_headers(client):
    """Test that trace headers are in response."""
    response = client.get('/people')
    assert 'X-Trace-ID' in response.headers
    assert 'X-Request-ID' in response.headers

def test_logging_structured(caplog):
    """Test that logs are structured JSON."""
    app = create_app('testing')
    with app.test_client() as client:
        with caplog.at_level(logging.INFO):
            client.get('/people')
    
    # Check that log contains expected fields
    assert any('request_id' in record.message for record in caplog.records)
```

## 9. Performance Tuning

### Sampling for Production

```python
# High-volume production: 5% sampling
OTEL_TRACES_SAMPLER_ARG=0.05

# Mission-critical: 50% sampling
OTEL_TRACES_SAMPLER_ARG=0.5

# Development: 100% sampling
OTEL_TRACES_SAMPLER_ARG=1.0
```

### Batch Processor Settings

```python
# In tracing.py
tracer_provider.add_span_processor(
    BatchSpanProcessor(
        otlp_exporter,
        schedule_delay_millis=5000,  # Export every 5s
        max_queue_size=2048,
        max_export_batch_size=512,
        export_timeout_millis=30000,
    )
)
```

### Memory Optimization

```python
# Reduce histogram buckets for high-volume metrics
api_response_latency_seconds = Histogram(
    'api_response_latency_seconds',
    'API response latency in seconds',
    ['endpoint', 'method'],
    buckets=(0.01, 0.1, 1.0, 5.0),  # Fewer buckets = less memory
)
```

## 10. Troubleshooting

### Metrics not appearing
```bash
curl http://localhost:5000/metrics
# Should show: api_requests_total, api_response_latency_seconds, etc.
```

### Traces not in Jaeger
```bash
# Check OTEL SDK is enabled
curl http://localhost:5000/health/live
# Check trace headers in response
curl -i http://localhost:5000/health/live | grep X-Trace-ID
```

### Logs missing trace_id
```bash
# Ensure LOG_FORMAT=json is set
# Check logs are valid JSON:
kubectl logs deployment/titanic-api -n titanic-api | jq .trace_id
```

## Reference

- [OpenTelemetry Python Docs](https://opentelemetry.io/docs/instrumentation/python/)
- [Flask Instrumentation](https://opentelemetry.io/docs/instrumentation/python/autoinstrumentation/)
- [Prometheus Python Client](https://github.com/prometheus/client_python)
- [JSON Logging](https://github.com/madzak/python-json-logger)
