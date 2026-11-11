import os
import uvicorn
from laya.serve import create_app
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware

# Initialize standard Laya FastAPI app with preloaded checkpoints
app = create_app()

# Enable CORS for cross-domain / dev access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

UI_FILE = os.environ.get("LAYA_UI_FILE", "/app/laya-ui/index.html")

@app.get("/", response_class=HTMLResponse)
async def serve_index():
    if os.path.exists(UI_FILE):
        return FileResponse(UI_FILE, media_type="text/html")
    return HTMLResponse("<h1>Laya Decision Studio</h1><p>UI loading or file not found at " + UI_FILE + "</p>")

if __name__ == "__main__":
    host = os.environ.get("LAYA_HOST", "0.0.0.0")
    port = int(os.environ.get("LAYA_PORT", "8000"))
    log_level = os.environ.get("LAYA_LOG_LEVEL", "info")
    uvicorn.run(app, host=host, port=port, log_level=log_level)
