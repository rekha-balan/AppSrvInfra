{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "SystemPrefixName": {
      "type": "string",
      "defaultValue": "fsdi-appsrvinfra-test",
      "metadata": {
        "description": "String to append to all resource names"
      }
    },
    "Region": {
      "type": "string",
      "defaultValue": "Central US",
      "metadata": {
        "description": "Region for the deployment"
      }
    },
    "vnetAddressSpace": {
      "type": "string",
      "defaultValue": "10.12.212.0/24",
      "metadata": {
        "description": "IP Address Of Virtual Network With CIDR"
      }
    },
    "WAFSubnetAddressSpace": {
      "type": "string",
      "defaultValue": "10.12.212.224/27",
      "metadata": {
        "description": "WAF Subnet IP Address With CIDR Block"
      }
    },
    "WebAppSubnetAddressSpace": {
      "type": "string",
      "defaultValue": "10.12.213.0/26",
      "metadata": {
        "description": "Web App Subnet IP Address With CIDR Block"
      }
    },
    "BackendSubnetAddressSpace": {
      "type": "string",
     "defaultValue": "10.12.212.128/26",
      "metadata": {
        "description": "Backend VM Subnet IP Address With CIDR Block"
      }
    },
    "WebAppSubnetPrefix": {
      "type": "string",
      "defaultValue": "10.12.213.0",
      "metadata": {
       "description": "Web App Subnet IP Address With CIDR Block"
      }
    },
    "WebDNS": {
      "type": "string",
      "defaultValue": "cargill-fms.com",
      "metadata": {
        "description": "Set this to the root domain associated with the Web App."
      }
    },
    "internalLoadBalancingMode": {
      "type": "int",
      "defaultValue": 3,
      "metadata": {
        "description": "0 = public VIP only, 1 = only ports 80/443 are mapped to ILB VIP, 2 = only FTP ports are mapped to ILB VIP, 3 = both ports 80/443 and FTP ports are mapped to an ILB VIP."
      }
    },
    "applicationGatewaySize": {
      "type": "string",
      "allowedValues": [
        "WAF_Small",
        "WAF_Medium",
        "WAF_Large"
      ],
      "defaultValue": "WAF_Medium",
      "metadata": {
        "description": "WAF Appliaction Gateway Size"
      }
    },
    "wafEnabled": {
      "type": "bool",
    "defaultValue": true,
      "metadata": {
        "description": "WAF Enabled"
      }
    },
    "WafCapacity": {
      "type": "int",
      "allowedValues": [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10
      ],
      "defaultValue": 3,
      "metadata": {
        "description": "Number of WAF Instances"
      }
    },
    "sqlAdministratorLogin": {
      "type": "string",
      "metadata": {
        "description": "The administrator username of the SQL Server."
      }
    },
    "sqlAdministratorLoginPassword": {
      "type": "securestring",
      "metadata": {
        "description": "The administrator password of the SQL Server."
     }
    },
    "poolDtu": {
      "type": "string",
      "defaultValue": 250,
      "metadata": {
        "description": "The eDTU value of the entire elastic pool."
      }
    },
    "databaseDtuMax": {
      "type": "string",
      "defaultValue": "125",
      "metadata": {
        "description": "The eDTU value of and database within the elastic pool."
      }
    }
  },
  "variables": {
    "vnetName": "[toLower(concat(parameters('SystemPrefixName'),'-vnet'))]",
    "WafSubnetName": "[toLower(concat(parameters('SystemPrefixName'),'-agw-snet'))]",
    "WebAppSubnetName": "[toLower(concat(parameters('SystemPrefixName'),'-ase-snet'))]",
    "BackendSubnetName": "[toLower(concat(parameters('SystemPrefixName'),'-be-snet'))]",
    "aseWebName": "[toLower(concat(parameters('SystemPrefixName'),'-ase'))]",
    "applicationGatewayName": "[toLower(concat(parameters('SystemPrefixName'),'-agw'))]",
    "sqlServerName": "[toLower(concat(parameters('SystemPrefixName'),'-sqlsrv'))]",
    "databaseName": "[toLower(concat(parameters('SystemPrefixName'),'-db'))]",
    "elasticPoolName": "[toLower(concat(parameters('SystemPrefixName'),'-ep'))]",
  
    "TemplateURIs": "https://raw.githubusercontent.com/mtrgoose/AppSrvInfra/master/ase-ilb-blueprint/templates/",
    "_StorageTemplateURIs": "https://<yourstorage>.blob.core.windows.net/arm/blueprint/",
    
    "elasticPooledition": "PremiumRS",
    
    "wafMode": "Prevention",
    "wafRuleSetType": "OWASP",
    "wafRuleSetVersion": "3.0",

    "VaultName": "[concat(parameters('SystemPrefixName'),'-kv')]",
    "VaultSKU": "Premium",
  
    "appServicePlanNameWeb": "[concat(parameters('SystemPrefixName'),'-asp')]",

    "VnetID": "[concat(resourceId('Microsoft.Network/VirtualNetworks', variables('vnetName')))]",
    
    "WAFBackEndPoolSplit": "[split(parameters('WebAppSubnetPrefix'),'.')]",
    "WAFBackEndPoolConvert": "[int(variables('WAFBackEndPoolSplit')[3])]",
    "WAFBackEndPoolAdd": "[add(variables('WAFBackEndPoolConvert'),4)]",
    "WAFBackEndPoolLastOctet": "[string(variables('WAFBackEndPoolAdd'))]",
    "WAFBackEndPoolStaticIP1": "[concat(variables('WAFBackEndPoolSplit')[0],'.',variables('WAFBackEndPoolSplit')[1],'.',variables('WAFBackEndPoolSplit')[2],'.',variables('WAFBackEndPoolLastOctet'))]",

    "Secretname": "SqlSecret"
  },
  "resources": [
    {
      "type": "Microsoft.Resources/deployments",
      "name": "[variables('VaultName')]",
      "apiVersion": "2015-01-01",
      "properties": {
        "mode": "Incremental",
        "templateLink": {
          "uri": "[concat(variables('TemplateURIs'),'keyvault.json')]",
          "contentVersion": "1.0.0.0"
        },
        "parameters": {
          "VaultName": { "value": "[variables('VaultName')]" },
          "Region": { "value": "[parameters('Region')]" },
          "VaultSku": { "value": "[variables('VaultSKU')]" },
          "SecretName": { "value": "[variables('SecretName')]" },
          "SecretValue": { "value": "[parameters('sqlAdministratorLoginPassword')]" }
        }
      }
    },
    {
      "type": "Microsoft.Resources/deployments",
      "name": "[variables('vnetName')]",
      "apiVersion": "2015-01-01",
      "properties": {
        "mode": "Incremental",
        "template": {
          "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
          "contentVersion": "1.0.0.0",
          "variables": {
            "vnetID": "[resourceId('Microsoft.Network/virtualNetworks',variables('vnetName'))]"
          },
          "resources": [
            {
              "apiVersion": "2016-03-30",
              "type": "Microsoft.Network/virtualNetworks",
              "name": "[variables('vnetName')]",
              "location": "[parameters('Region')]",
              "properties": {
                "addressSpace": {
                  "addressPrefixes": [
                    "[parameters('vnetAddressSpace')]"
                  ]
                },
                "subnets": [
                  {
                    "name": "[variables('WAFSubnetName')]",
                    "properties": {
                      "addressPrefix": "[parameters('WAFSubnetAddressSpace')]"
                    }
                  },
                  {
                    "name": "[variables('WebAppSubnetName')]",
                    "properties": {
                      "addressPrefix": "[parameters('WebAppSubnetAddressSpace')]"
                    }
                  },
                  {
                    "name": "[variables('BackendSubnetName')]",
                    "properties": {
                      "addressPrefix": "[parameters('BackendSubnetAddressSpace')]"
                    }
                  }
                ]
              }
            }
          ]
        }
      }
    },
    {
      "type": "Microsoft.Resources/deployments",
      "name": "[variables('aseWebName')]",
      "apiVersion": "2016-09-01",
      "dependsOn": ["[variables('vnetName')]"],
      "properties": {
        "mode": "Incremental",
        "templateLink": {
          "uri": "[concat(variables('TemplateURIs'),'ilbase.json')]",
          "contentVersion": "1.0.0.0"
        },
        "parameters": {
          "aseName": { "value": "[variables('aseWebName')]" },
          "Region": { "value": "[parameters('Region')]" },
          "vnetID": { "value": "[variables('vnetID')]" },
          "SubnetName": { "value": "[variables('WebAppSubnetName')]" },
          "internalLoadBalancingMode": { "value": "[parameters('internalLoadBalancingMode')]" },
          "DNS": { "value": "[parameters('WebDNS')]" }
        }
      }
    },
    {
      "type": "Microsoft.Resources/deployments",
      "name": "[variables('appServicePlanNameWeb')]",
      "apiVersion": "2016-09-01",
      "dependsOn": ["[variables('aseWebName')]"],
      "properties": {
        "mode": "Incremental",
        "templateLink": {
          "uri": "[concat(variables('TemplateURIs'),'ilbaseasp.json')]",
          "contentVersion": "1.0.0.0"
        },
        "parameters": {
          "appServicePlanName": { "value": "[variables('appServicePlanNameWeb')]" },
          "aseName": { "value": "[variables('aseWebName')]" },
          "Region": { "value": "[parameters('Region')]" }
        }
      }
    },
    {
      "type": "Microsoft.Resources/deployments",
      "name": "[variables('applicationGatewayName')]",
      "apiVersion": "2015-01-01",
      "dependsOn": ["[variables('aseWebName')]"],
      "properties": {
        "mode": "Incremental",
        "templateLink": {
          "uri": "[concat(variables('TemplateURIs'),'waf.json')]",
          "contentVersion": "1.0.0.0"
        },
        "parameters": {
          "vnetName": { "value": "[variables('vnetName')]" },
          "WAFSubnetName": { "value": "[variables('WAFSubnetName')]" },
          "Region": { "value": "[parameters('Region')]" },
          "subnetPrefix": { "value": "[parameters('WAFSubnetAddressSpace')]" },
          "addressPrefix": { "value": "[parameters('vnetAddressSpace')]" },
          "applicationGatewayName": { "value": "[variables('applicationGatewayName')]" },
          "applicationGatewaySize": { "value": "[parameters('applicationGatewaySize')]" },
          "capacity": { "value": "[parameters('WafCapacity')]" },
          "wafMode": { "value": "[variables('wafMode')]" },
          "wafRuleSetType": { "value": "[variables('wafRuleSetType')]" },
          "wafRuleSetVersion": { "value": "[variables('wafRuleSetVersion')]" },
          "backendIpAddress1": { "value": "[variables('WAFBackEndPoolStaticIP1')]" },
          "wafEnabled": { "value": "[parameters('wafEnabled')]" },
          "webAppDNS": { "value": "[parameters('WebDNS')]" }
        }
      }
    },
    {
      "type": "Microsoft.Resources/deployments",
      "name": "[variables('sqlServerName')]",
      "apiVersion": "2015-01-01-preview",
      "properties": {
        "mode": "Incremental",
        "templateLink": {
          "uri": "[concat(variables('TemplateURIs'),'azuresql.json')]",
          "contentVersion": "1.0.0.0"
        },
        "parameters": {
          "sqlAdministratorLogin": { "value": "[parameters('sqlAdministratorLogin')]" },
          "sqlAdministratorLoginPassword": { "value": "[parameters('sqlAdministratorLoginPassword')]" },
          "location": { "value": "[parameters('Region')]" },
          "sqlServerName": { "value": "[variables('sqlServerName')]" },
          "databaseName": { "value": "[variables('databaseName')]" },
          "elasticPoolName": {"value": "[variables('elasticPoolName')]"},
          "elasticPooledition": {"value": "[variables('elasticPooledition')]"},
          "poolDtu": {"value": "[parameters('poolDtu')]"},
          "databaseDtuMax": {"value": "[variables('databaseDtuMax')]"}
        }
      }
    }
  ],
  "outputs": {
    "AseWebName": {
      "type": "string",
      "value": "[variables('aseWebName')]"
    },
    "VnetName": {
      "type": "string",
      "value": "[variables('vnetName')]"
    },
    "SqlName": {
      "type": "string",
      "value": "[variables('sqlServerName')]"
    },
    "AppGWName": {
      "type": "string",
      "value": "[variables('applicationGatewayName')]"
    }
  }
}
