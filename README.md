# Pterodactyl Script

**A script to easily install and manage Pterodactyl.**

## Installation

```bash
curl https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/v0.1/install.sh -O
```

```bash
sudo bash install.sh
```

## Features

### Installation and Updating:
* **MariaDB** ( with databases and users )
* **Panel** ( with nginx, php, ... )
* **Wings** ( with docker and swap)
* **phpMyAdmin** ( with nginx, php, ... )

### More
* Automatic configuration of Firewall (UFW) 
* Automatic certificates from Let's Encrypt 

## Supported Systems:

| Operating System | Version | Architectures | Supported          |
| ---------------- |---------| ------------- | ------------------ |
| Ubuntu           | 16.04   | x86_64        | :x:                |
|                  | 18.04   | x86_64        | :heavy_check_mark: |
|                  | 20.04   | x86_64        | :heavy_check_mark: |
| Debian           | 9       | x86_64        | :x:                |
|                  | 10      | x86_64        | :heavy_check_mark: |
|                  | 11      | x86_64        | :heavy_check_mark: |

## Advanced options

**You can disable or customize specific services. To customize, you can provide the following keys and values when you run the program:**

| Key               | Values         | Default           | Description                                  |
| ----------------- | -------------- | ----------------- | -------------------------------------------- |
| SETUP_FIREWALL    | `true` `false` | true              | _Setting up the Firewall?_                   |
| SETUP_LETSENCRYPT | `true` `false` | true              | _Setting up the Let's Encrypt certificates?_ |
| NGINX_SSL         | `true` `false` | true              | _Setting up SSL on the Nginx Web Server?_    |
| NGINX_HSTS        | `true` `false` | true              | _Setting up HSTS on the Nginx Web Server?_   |
| PASSWORD_LENGTH   | `8...128`      | 64                | _Password length from Password Generator_    |
| DBPANEL_DB        | `[a-z]`        | "panel"           | _DB Name for Panel Database Setup_           |
| DBPANEL_USER      | `[a-z]`        | "pterodactyl"     | _DB User for Panel Database Setup_           |
| DBPANEL_PASSWORD  | `""` `[a-z]`   | ""                | _DB Password for Panel Database Setup_       |
| DBHOST_USER       | `[a-z]`        | "pterodactyluser" | _DB Name for Server Database Setup_          |
| DBHOST_PASSWORD   | `""` `[a-z]`   | ""                | _DB Password for Server Database Setup_      |
| DB_ROOT_PASSWORD  | `""` `[a-z]`   | ""                | _Root Password for Database Setup_           |

### Usage
```bash
sudo SETUP_FIREWALL=false bash install.sh
```
