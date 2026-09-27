from flask import Flask
import socket

app = Flask(__name__)

@app.route("/")
def home():
    hostname = socket.gethostname()

    return f"""
    <html>
        <head>
            <title>Olu Azure HA Project</title>
        </head>

        <body>
            <h1>Olu's Highly Available Azure Application</h1>

            <h2>System Status: ONLINE</h2>

            <p>This application is running successfully.</p>

            <p>Server responding: {hostname}</p>

            <p>Platform: Microsoft Azure</p>
        </body>
    </html>
    """

@app.route("/health")
def health():
    return "healthy", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
