# Dev Center Catalog Setup

This repository contains resources that can be used as a **catalog for your Azure Dev Center**.

# Overview

A directory within this repository can be configured as a catalog source for your Dev Center.
To enable this, you need to attach the repository’s **`.git` URL** to your Dev Center catalog configuration.

---

# Contents

This directory includes the required files to define and deploy an environment:

1. `env.ARM.template.json`

* A parameterized ARM template used to deploy an Azure Virtual Machine.
* The VM is created using a **Marketplace image**, along with all necessary networking components.
* Each parameter includes metadata descriptions explaining its purpose.

---

2. `environment.yaml`

* Defines metadata for the environment.
* Used by Dev Center to understand how to present and deploy the environment.


# Summary

This setup enables:

* Reusable environment definitions
* Automated VM provisioning
* Integration with Azure Dev Center catalogs

