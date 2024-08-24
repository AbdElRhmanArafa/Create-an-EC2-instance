# Module 3: Activity 3 - Troubleshoot Creating an EC2 Instance Using the AWS CLI

## Overview

In this activity, you will use the AWS Command Line Interface (AWS CLI) to launch an Amazon Elastic Compute Cloud (Amazon EC2) instance in the `eu-west-2` (London) Region. The instance will be configured with an Apache web server, a MariaDB relational database, and PHP, collectively forming a LAMP stack. This setup will host an updated version of the Mom & Pop Café website that supports online customer orders.

## Objectives

By the end of this activity, you will be able to:
- Launch an Amazon EC2 instance using the AWS CLI.
- Troubleshoot AWS CLI commands and Amazon EC2 service settings.

## Business Case

### Requirement for Mom & Pop Café: Online Orders

Mom and Pop were impressed by the initial version of their café's website, which provided essential information. However, many customers requested the ability to place orders online. In this activity, you will upgrade the website to support online orders, taking on the roles of Darsh and Sophie to implement these changes.

## Activity Steps

### Duration

Approximately 45 minutes.

### 1. Accessing the AWS Management Console

1. Click **Start Lab** to launch your lab.
2. Wait for the status to change to "Lab status: ready," then close the Start Lab panel.
3. Click **AWS** to open the AWS Management Console in a new browser tab. If the tab doesn't open automatically, allow pop-ups in your browser.
4. Arrange the AWS Management Console tab alongside these instructions for easy reference.

### 2. Connect to an Amazon Linux EC2 Instance Using SSH

#### 2.1 Windows Users

1. Choose **Details** and click **Show** to access the Credentials window.
2. Download the `labsuser.ppk` file and save it to your Downloads directory.
3. Download and install PuTTY if you don't have it already.
4. Open PuTTY and configure it:
   - Go to **Connection** and set **Seconds between keepalives** to 30.
   - In **Session**, enter the Public DNS or IPv4 address of the Bastion Host instance.
   - Under **Connection > SSH > Auth**, browse to the `labsuser.ppk` file and select it.
   - Click **Open** and accept the connection.
5. Login as `ec2-user` to connect to the instance.

#### 2.2 macOS/Linux Users

1. Choose **Details** and click **Show** to access the Credentials window.
2. Download the `labsuser.pem` file and save it.
3. Open a terminal and navigate to the directory where `labsuser.pem` was downloaded:
   ```sh
   cd ~/Downloads
   ```
4. Change the permissions of the key file:
   ```sh
   chmod 400 labsuser.pem
   ```
5. In the AWS Management Console, find the Public IPv4 address of the instance.
6. Use SSH to connect:
   ```sh
   ssh -i labsuser.pem ec2-user@<public-ip>
   ```
   Type `yes` to accept the connection.

### 3. Configure the AWS CLI

1. Run the following command to configure the AWS CLI:
   ```sh
   aws configure
   ```
2. Enter the following details when prompted:
   - **AWS Access Key ID**: (Copy from the Credentials window)
   - **AWS Secret Access Key**: (Copy from the Credentials window)
   - **Default region name**: `eu-west-2`
   - **Default output format**: `json`

### 4. Create an EC2 Instance Using the AWS CLI

#### 4.1 Review the Script

1. Navigate to the script directory and create a backup:
   ```sh
   cd ~/sysops-activity-files/starters
   cp create-lamp-instance.sh create-lamp-instance.backup
   ```
2. Open and review the `create-lamp-instance.sh` script using a text editor like `vi`:
   ```sh
   vi create-lamp-instance.sh
   ```

   **Script Overview:**
   - **Lines 1-11**: Defines instance size and settings.
   - **Lines 16-29**: Queries AWS regions and finds the VPC.
   - **Lines 31-57**: Retrieves necessary IDs for the instance.
   - **Lines 59-124**: Cleans up existing resources.
   - **Lines 126-154**: Creates a security group.
   - **Lines 156-168**: Launches the EC2 instance.
   - **Lines 179-188**: Waits for a public IP address and retrieves it.

3. Review the `create-lamp-instance-userdata.txt` file to understand the user-data script:
   ```sh
   cat create-lamp-instance-userdata.txt
   ```

#### 4.2 Run the Script

1. Execute the script:
   ```sh
   ./create-lamp-instance.sh
   ```
2. If prompted to delete existing security groups or instances, choose `yes` (Y). Expect the script to fail due to intentional issues.

#### 4.3 Troubleshoot Issues

**Issue #1: Invalid Subnet ID**

- Verify subnet ID existence using AWS CLI or EC2 Console.
- Adjust the script if necessary and re-run it.

**Issue #2: Permission Denied on SSH**

- Ensure you are using the correct key pair file with `chmod 400` permissions.
- Confirm the default user for Amazon Linux 2 is `ec2-user`.

**Issue #3: Webpage Not Loading**

- Check if the web server is running on port 80.
- Use `nmap` to verify port accessibility:
  ```sh
  sudo yum install -y nmap
  nmap -Pn <public-ip>
  ```

### 5. Verify the Functionality of the New Website

1. Load the website in a browser:
   ```sh
   http://<public-ip>/mompopcafe/
   ```
2. Test placing orders and view the order history.

   Ensure the order details are captured and stored in the database.
