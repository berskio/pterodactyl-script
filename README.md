# Pterodactyl Script

**A script to easily install and manage Pterodactyl.**

## Installation

```bash
curl https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/master/install.sh | sudo bash
```

## Features

### Installation and Updating:
* **Panel** ( with mysql, nginx, php, ... )
* **Wings** ( with docker, mysql )
* **phpMyAdmin** ( with nginx, php, ... )

### More
* Automatic certificates from Let's Encrypt 
* Automatic configuration of Firewall (UFW) 

## Supported Systems:

| Operating System | Version | Architectures | Supported          |
| ---------------- |---------| ------------- | ------------------ |
| Ubuntu           | 16.04   | x86_64        | :x:                |
|                  | 18.04   | x86_64        | :heavy_check_mark: |
|                  | 20.04   | x86_64        | :heavy_check_mark: |
| Debian           | 9       | x86_64        | :x:                |
|                  | 10      | x86_64        | :heavy_check_mark: |
|                  | 11      | x86_64        | :heavy_check_mark: |

## Advanced Mode

**You can disable or customize specific services. To customize, you can run the script in advanced mode:**

```bash
curl https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/master/install.sh | sudo bash advanced
```
