from flask import Flask
from .config import app_config
from .models import db
from .views.people import people_api as people


def create_app(env_name: str) -> Flask:
    """
    Initializes the application registers

    Parameters:
        env_name: the name of the environment to initialize the app with

    Returns:
        The initialized app instance
    """
    app = Flask(__name__)
    app.config.from_object(app_config[env_name])
    db.init_app(app)

    with app.app_context():
        db.create_all()
        print("Tables created")

    app.register_blueprint(people, url_prefix="/")

    @app.route('/', methods=['GET'])
    def index():
        """
        Root endpoint for populating root route

        Returns:
            Greeting message
        """
        return """
        Welcome to the Titanic API
        """

    @app.route('/health/live', methods=['GET'])
    def health_live():
        """
        Liveness probe endpoint - indicates if app is running

        Returns:
            JSON status response with 200 OK
        """
        return {'status': 'alive', 'service': 'titanic-api'}, 200

    @app.route('/health/ready', methods=['GET'])
    def health_ready():
        """
        Readiness probe endpoint - indicates if app is ready to accept traffic
        Checks database connectivity

        Returns:
            JSON status response with 200 OK if ready, 503 if not ready
        """
        try:
            with app.app_context():
                db.session.execute('SELECT 1')
            return {'status': 'ready', 'service': 'titanic-api', 'database': 'connected'}, 200
        except Exception as e:
            app.logger.error(f"Health check failed: {str(e)}")
            return {'status': 'not ready', 'service': 'titanic-api', 'database': 'disconnected', 'error': str(e)}, 503

    return app
