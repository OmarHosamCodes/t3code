import { defineRailway, github, preserve, project, service, volume } from "railway/iac";

// Other services share the Internal Tools / Usefull environment. This partial
// owns only the T3 Code service and its volume.
export const partial = "t3-code";

export default defineRailway(() => {
  const home = volume("t3-code-volume", {
    region: "europe-west4-drams3a",
    sizeMB: 50000,
  });

  const t3 = service("T3 Code", {
    source: github("OmarHosamCodes/t3code", { branch: "main" }),
    build: { builder: "DOCKERFILE" },
    healthcheck: "/healthcheck",
    healthcheckTimeout: 300,
    volumeMounts: {
      "/home/t3": home,
    },
    env: {
      T3_SETUP_PASSWORD: preserve(),
    },
  });

  return project("Internal Tools", {
    resources: [t3, home],
  });
});
