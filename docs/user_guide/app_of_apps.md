# App of Apps

There is a pattern in Argo CD for declaratively bootstrapping the entire cluster from a single application. This pattern is called [App of Apps](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern).

As with n1x all applications are declared within a single (modular) configuration, it's aware of all applications that are enabled. Therefore it can automatically generate an application with all other enabled applications (i.e. App of Apps).

## Enabling App of Apps

The App of Apps application is not enabled by default but can easily be enabled with the following configuration option.

``` nix title="configuration.nix"
{...}: {
  n1x.appOfApps.enable = true;

  # ...
}
```

And now when listing available applications the `apps` application has been added to the list. The name of the application can be changed with `n1x.appOfApps.name`.

```bash
>> nix run github:arnarg/n1x# -- list .#
apps - Argo CD app-of-apps with all applications that have inAppOfApps enabled.
argocd - Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes.
cilium - eBPF-based Networking, Security, and Observability.
csi-driver-nfs - CSI Kubernetes storage driver to use NFS server for persistent volumes.
```

And rendering this application will output Argo CD `Application`s for all of the listed applications.

```bash
>> nix run github:arnarg/n1x# -- render .#apps
apiVersion: argoproj.io/v1alpha1                                               
kind: Application                                                              
metadata:                                                                      
  name: argocd                                                                 
  namespace: argocd                                                            
spec:                                                                          
  destination:                                                                 
    namespace: argocd                                                          
    server: https://kubernetes.default.svc                                     
  plugin:                                                                      
    parameters:                                                                
      - name: application                                                      
        string: argocd                                                         
  project: default                                                             
  source:                                                                      
    repoURL: git@github.com:arnarg/n1x.git                                     
    targetRevision: HEAD                                                       
---                                                                            
apiVersion: argoproj.io/v1alpha1                                               
kind: Application                                                              
metadata:                                                                      
  name: cilium                                                                 
  namespace: argocd                                                            
spec:                                                                          
  destination:                                                                 
    namespace: kube-system                                                     
    server: https://kubernetes.default.svc                                     
  plugin:                                                                      
    parameters:                                                                
      - name: application                                                      
        string: cilium                                                         
  project: default                                                             
  source:                                                                      
    repoURL: git@github.com:arnarg/n1x.git                                     
    targetRevision: HEAD
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: csi-driver-nfs
  namespace: argocd
spec:
  destination:
    namespace: kube-system
    server: https://kubernetes.default.svc
  plugin:
    parameters:
      - name: application
        string: csi-driver-nfs
  project: default
  source:
    repoURL: git@github.com:arnarg/n1x.git
    targetRevision: HEAD
```
