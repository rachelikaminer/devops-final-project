"""Kanban task board - Flask app that stores tasks in a JSON file."""
import json
import os
import threading
import uuid

from flask import Flask, jsonify, render_template, request

STATUSES = ("todo", "in_progress", "done")
DB_PATH = os.environ.get(
    "DB_PATH",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "database", "db.json"),
)

app = Flask(__name__)
db_lock = threading.Lock()


def load_tasks():
    """Read all tasks from the JSON file (empty list if it does not exist yet)."""
    if not os.path.exists(DB_PATH):
        return []
    with open(DB_PATH, encoding="utf-8") as db_file:
        return json.load(db_file)


def save_tasks(tasks):
    """Write to a temp file first, then rename - so a crash never leaves a half-written db.json."""
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    temp_path = DB_PATH + ".tmp"
    with open(temp_path, "w", encoding="utf-8") as db_file:
        json.dump(tasks, db_file, ensure_ascii=False, indent=2)
    os.replace(temp_path, DB_PATH)


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/health")
def health():
    return jsonify(status="ok")


@app.route("/api/tasks", methods=["GET"])
def list_tasks():
    with db_lock:
        return jsonify(load_tasks())


@app.route("/api/tasks", methods=["POST"])
def create_task():
    data = request.get_json(silent=True) or {}
    title = str(data.get("title", "")).strip()
    if not title:
        return jsonify(error="title is required"), 400

    task = {"id": uuid.uuid4().hex, "title": title, "status": "todo"}
    with db_lock:
        tasks = load_tasks()
        tasks.append(task)
        save_tasks(tasks)
    return jsonify(task), 201


@app.route("/api/tasks/<task_id>", methods=["PATCH"])
def update_task(task_id):
    data = request.get_json(silent=True) or {}
    status = data.get("status")
    if status not in STATUSES:
        return jsonify(error=f"status must be one of {STATUSES}"), 400

    with db_lock:
        tasks = load_tasks()
        for task in tasks:
            if task["id"] == task_id:
                task["status"] = status
                save_tasks(tasks)
                return jsonify(task)
    return jsonify(error="task not found"), 404


@app.route("/api/tasks/<task_id>", methods=["DELETE"])
def delete_task(task_id):
    with db_lock:
        tasks = load_tasks()
        remaining = [task for task in tasks if task["id"] != task_id]
        if len(remaining) == len(tasks):
            return jsonify(error="task not found"), 404
        save_tasks(remaining)
    return "", 204


if __name__ == "__main__":
    # 0.0.0.0 is required inside a container; the VM itself will expose the port on 127.0.0.1 only.
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "5000")))
