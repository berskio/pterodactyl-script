<?php
/* Servers configuration */
$i = 0;

/* Server: MariaDB [1] */
$i++;
$cfg['Servers'][$i]['verbose'] = 'MariaDB';
$cfg['Servers'][$i]['host'] = 'localhost';
$cfg['Servers'][$i]['port'] = '3306';
$cfg['Servers'][$i]['socket'] = '';
$cfg['Servers'][$i]['auth_type'] = 'cookie';
$cfg['Servers'][$i]['user'] = 'root';
$cfg['Servers'][$i]['password'] = '';
$cfg['Servers'][$i]['AllowRoot'] = false;

/* End of servers configuration */

$cfg['blowfish_secret'] = '<blowfish>';
$cfg['DefaultLang'] = 'de';
$cfg['ServerDefault'] = 1;
$cfg['UploadDir'] = '';
$cfg['SaveDir'] = '';
