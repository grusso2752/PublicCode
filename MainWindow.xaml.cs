using System;
﻿using Microsoft.Win32;
using System.Diagnostics;
using System.Linq;
using System.Net.NetworkInformation;
using System.Windows;
using System.Management;
using System.Net;

namespace UtilityBelt
{
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();
        }

        private void Hostname_Initialized(object sender, System.EventArgs e)
        {
            Hostname.Content = "Hostname: " + (System.Environment.MachineName);
        }

        private void Username_Initialized(object sender, System.EventArgs e)
        {
            Username.Content = "Username: " + System.Security.Principal.WindowsIdentity.GetCurrent().Name;
        }

        private void IP_Address_Initialized(object sender, System.EventArgs e)
        {
            string networkadapterquery = "SELECT * FROM Win32_NetworkAdapterConfiguration";

            ManagementObjectSearcher networkadapter = new ManagementObjectSearcher(networkadapterquery);
            ManagementObjectCollection nics = networkadapter.Get();

            foreach (ManagementObject nic in nics)
            {
                string wifiadapter = "Intel(R) Dual Band Wireless-AC 8265";
                string win7adapter = "Intel(R) PRO/1000 MT Network Connection";
                string sccmadapter = "Intel(R) 82574L Gigabit Network Connection";

                if (nic["Description"].ToString().Contains(wifiadapter))
                {
                    string[] addresses = (string[])nic["IPAddress"];
                    IP_Address.Content = "IP Address: " + addresses[0];
                }
                else if (nic["Description"].ToString().Contains(win7adapter))
                {
                    string[] addresses = (string[])nic["IPAddress"];
                    IP_Address.Content = "IP Address:" + addresses[0];
                }
                else
                {
                    if (nic["Description"].ToString().Contains(sccmadapter)) 
                    {
                        string[] addresses = (string[])nic["IPAddress"];
                        IP_Address.Content = "IP Address:" + addresses[0];
                    }
                }

            }
            IPHostEntry ipEntry = System.Net.Dns.GetHostEntry(System.Net.Dns.GetHostName());
            IPAddress[] addr = ipEntry.AddressList;

            string OSVersion = Registry.GetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "CurrentVersion", "").ToString();

            if (OSVersion == "6.3")
            {
                string ip = addr[2].ToString();
                IP_Address.Content = "IP Address: " + ip;
            }
            if (OSVersion == "6.1")
            {
                string ip = addr[0].ToString();
                IP_Address.Content = "IP Address: " + ip;
            }
        }

        private void MAC_Address_Initialized(object sender, System.EventArgs e)
        {
            var macAddr = (from nic in NetworkInterface.GetAllNetworkInterfaces()
            where nic.OperationalStatus == OperationalStatus.Up
            select nic.GetPhysicalAddress().ToString()).FirstOrDefault();
            MAC_Address.Content = "MAC Address: "+ macAddr;
        }

        private void Domain_Initialized(object sender, System.EventArgs e)
        {
            Domain.Content = "Domain: " + System.Environment.UserDomainName;
        }

        private void Manage_SCCM_Click(object sender, RoutedEventArgs e)
        {
            System.Diagnostics.Process.Start(@"C:\Windows\CCM\ClientUX\SCClient.exe");
        }

        private void Bump_SCCM_Click(object sender, RoutedEventArgs e)
        {
            System.Diagnostics.Process.Start("control", "smscfgrc");
        }

        private void Update_Group_Policy_Click(object sender, RoutedEventArgs e)
        {
            String gpupdate;
            gpupdate = "/C gpupdate /force";
            System.Diagnostics.Process.Start("CMD.exe", gpupdate);
        }

        private void Map_Network_Drives_Click(object sender, RoutedEventArgs e)
        {
            var DriveMappings = @"\\ahn.org\sysvol\ahn.org\EscFiles\Scripts\DriveMapping.ps1";
            var startInfo = new ProcessStartInfo()
            {
                FileName = "powershell.exe",
                Arguments = $"-NoProfile -ExecutionPolicy unrestricted -file \"{DriveMappings}\"",
                UseShellExecute = false
            };
            Process.Start(startInfo);
        }

        private void Reset_Network_Password_Click(object sender, RoutedEventArgs e)
        {
            System.Diagnostics.Process.Start("https://reset.ahn.org/");
        }

        private void Exit_Click(object sender, RoutedEventArgs e)
        {
            Close();
        }

        private void Label_Initialized(object sender, EventArgs e)
        {

        }
    }
}