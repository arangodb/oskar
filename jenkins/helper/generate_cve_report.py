import json
import os
from jinja2 import Environment, BaseLoader
from datetime import datetime
import sys

REPORT_HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>grype scan report</title>
    <style>
        h1 {
            text-align: left;
        }

        body {
            font-family: Arial, sans-serif;
            text-align: left;
        }

        table {
            width: 100%;
            border-collapse: collapse;
        }

        th,
        td {
            border: 1px solid black;
            padding: 8px;
            text-align: left;
        }

        th {
            background-color: #f2f2f2;
        }

        .nowrap-col {
            white-space: nowrap;
        }
    </style>
</head>

<body>
    <table>
        <tr>
            <td>Scan date</td>
            <td>{{ scan_date }}</td>
        </tr>
        <tr>
            <td>Grype version</td>
            <td>{{ grype_version }}</td>
        </tr>
        <tr>
            <td>CVE database build timestamp</td>
            <td>{{ db_date }}</td>
        </tr>
    </table>

    <label>
        <input type="checkbox" id="toggleCheckbox" checked> Show only CVEs with severity >= High
    </label>

    <table id="filtered-table" style = "display: table;">
        <th>Image tags</th>
        <th>Severity</th>
        <th>CVE ID</th>
        <th>Description</th>
        <th>Artifact name</th>
        <th>Artifact type</th>
        <th>Artifact version</th>
        <th>Fixed version(s)</th>
        <th>Locations(s)</th>
        <tbody id="table-body">
            {% for scan in scans %}
            {% for vulnerability in scan.vulnerabilities %}
            {% if vulnerability.severity == "Critical" or vulnerability.severity == "High" %}
            <tr>
                {% if loop.index == 1 %}
                <td class="nowrap-col" rowspan="{{ scan.row_count_high_critical }}">{{ scan.image_tags }}</td>
                {% endif %}
                <td bgcolor="pink">{{ vulnerability.severity }}</td>
                <td><a href="{{ vulnerability.dataSource }}">{{ vulnerability.id }}</a></td>
                <td>{{ vulnerability.description }}</td>
                <td>{{ vulnerability.artifact_name }}</td>
                <td>{{ vulnerability.artifact_type }}</td>
                <td>{{ vulnerability.artifact_version }}</td>
                <td>{{ vulnerability.fixed_versions }}</td>
                <td>
                {% for location in vulnerability.locations %}
                    {{ location.path }}<br>
                {% endfor %}
                </td>
            </tr>
            {% endif %}
            {% endfor %}
            {% endfor %}
        </tbody>
    </table>

    <table id="full-table" style="display: none;">
        <th>Image tags</th>
        <th>Severity</th>
        <th>CVE ID</th>
        <th>Description</th>
        <th>Artifact name</th>
        <th>Artifact type</th>
        <th>Artifact version</th>
        <th>Fixed version(s)</th>
        <tbody id="table-body">
            {% for scan in scans %}
            {% for vulnerability in scan.vulnerabilities %}
            <tr>
                {% if loop.index == 1 %}
                <td class="nowrap-col" rowspan="{{ scan.row_count_total }}">{{ scan.image_tags }}</td>
                {% endif %}
                {% if vulnerability.severity == "Critical" or vulnerability.severity == "High" %}
                <td bgcolor="pink">{{ vulnerability.severity }}</td>
                {% else %}
                <td>{{ vulnerability.severity }}</td>
                {% endif %}
                <td><a href="{{ vulnerability.dataSource }}">{{ vulnerability.id }}</a></td>
                <td>{{ vulnerability.description }}</td>
                <td>{{ vulnerability.artifact_name }}</td>
                <td>{{ vulnerability.artifact_type }}</td>
                <td>{{ vulnerability.artifact_version }}</td>
                <td>{{ vulnerability.fixed_versions }}</td>
            </tr>
            {% endfor %}
            {% endfor %}
        </tbody>
    </table>

    <script>
        document.getElementById("toggleCheckbox").addEventListener("change", function () {
            let fullTable = document.getElementById("full-table");
            let filteredTable = document.getElementById("filtered-table");

            if (this.checked) {
                filteredTable.style.display = "table";
                fullTable.style.display = "none";
            } else {
                filteredTable.style.display = "none";
                fullTable.style.display = "table";
            }
        });
    </script>

</body>

</html>

"""

if len(sys.argv) != 3:
    print("This script generates an HTML report from the JSON files output by the Grype scanner. Files must be named grypeResult*.json.\nUsage: python generate_cve_report.py [path to directory containing JSON files] [name of the HTML report file]")
    sys.exit(1)

results_path = sys.argv[1]
report_filename = sys.argv[2]

json_results = []
filenames = [f for f in os.listdir(results_path) if f.startswith("grypeResult") and f.endswith(".json")]
if len(filenames) == 0:
    print("No grypeResult*.json files found in the specified directory.")
    sys.exit(1)
for filename in filenames:
    file_path = os.path.join(results_path, filename)
    if os.path.isfile(file_path):
        with open(file_path, "r") as file:
            json_results.append(json.load(file))

report_data = {}
report_data["scan_date"] = json_results[0].get("descriptor", {}).get("timestamp", "")
report_data["grype_version"] = json_results[0].get("descriptor", {}).get("version", "")
report_data["db_date"] = json_results[0].get("descriptor", {}).get("descriptor", {}).get("db", {}).get("status", {}).get("from", {}).get("built", "")
report_data["scans"] = []

severity_order = {
    "Critical": 0,
    "High": 1,
    "Medium": 2,
    "Low": 3,
    "Negligible": 4,
    "Unknown": 5,
}

for result in json_results:
    table_entry = {}
    table_entry["image_tags"] = "<br>".join(result["source"]["target"]["tags"])
    table_entry["vulnerabilities"] = []
    for match in result["matches"]:
        vulnerability = match["vulnerability"]
        artifact = match.get("artifact", {})
        vulnerability_entry = {}
        vulnerability_entry["id"] = vulnerability.get("id", "")
        vulnerability_entry["dataSource"] = vulnerability.get("dataSource", "")
        vulnerability_entry["description"] = vulnerability.get("description", "")
        vulnerability_entry["severity"] = vulnerability.get("severity", "")
        vulnerability_entry["artifact_name"] = artifact.get("name", "")
        vulnerability_entry["artifact_type"] = artifact.get("type", "")
        vulnerability_entry["artifact_version"] = artifact.get("version", "")
        vulnerability_entry["fixed_versions"] = "<br>".join(
            vulnerability.get("fix", {}).get("versions", [])
        )
        vulnerability_entry["locations"] = artifact.get("locations", [])
        table_entry["vulnerabilities"].append(vulnerability_entry)
    table_entry["vulnerabilities"] = sorted(
        table_entry["vulnerabilities"],
        key=lambda x: severity_order.get(x["severity"], 5),
    )
    table_entry["row_count_total"] = len(table_entry["vulnerabilities"])
    table_entry["row_count_high_critical"] = len(
        [
            v
            for v in table_entry["vulnerabilities"]
            if v["severity"] in ["Critical", "High"]
        ]
    )
    report_data["scans"].append(table_entry)

template = Environment(loader=BaseLoader).from_string(REPORT_HTML_TEMPLATE)
html_output = template.render(report_data)

with open(report_filename, "w", encoding="utf-8") as file:
    file.write(html_output)
