# Pterodactyl Script

**A script to easily install and manage Pterodactyl.**

## Installation

```bash
wget https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/main/install.sh
sudo bash install.sh
```

## Features

### Installation and Updating:
* **Panel** ( with mysql, nginx, php, ... )
* **Wings** ( with docker, mysql )
* **phpMyAdmin** ( with nginx, php, ... )

### More
* Automatic certificates from Let's Encrypt 
* Automatic configuration of Firewall (UFW)
* Automatic PHP Version updates 

## Supported Systems:

| Operating System | Version | Architectures | Supported          |
| ---------------- |---------| ------------- | ------------------ |
| Ubuntu           | ≤ 18.04   | x86_64        | :x:                |
|                  | 20.04   | x86_64        | :heavy_check_mark: |
|                  | 22.04   | x86_64        | :heavy_check_mark: |
| Debian           | ≤ 9       | x86_64        | :x:                |
|                  | 10      | x86_64        | :heavy_check_mark: |
|                  | 11      | x86_64        | :heavy_check_mark: |

## Advanced Mode

**You can disable or customize specific services. To customize, you can run the script in advanced mode:**

```bash
sudo bash install.sh advanced
```
