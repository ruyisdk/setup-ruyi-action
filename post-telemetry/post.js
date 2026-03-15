const { execSync } = require("child_process");

try {
  console.log("Uploading ruyi telemetry data...");
  execSync("ruyi telemetry upload", { stdio: "inherit" });
} catch (error) {
  // Don't fail the job if telemetry upload fails
  console.log(`::warning::Failed to upload telemetry: ${error.message}`);
}
