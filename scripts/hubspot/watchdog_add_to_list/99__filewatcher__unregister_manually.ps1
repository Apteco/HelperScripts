

# List all registered filewatcher events
#Get-EventSubscriber -Force

# to choose and remove selected watchers, run below
Get-EventSubscriber -Force | Out-GridView -PassThru | Unregister-Event -Force

