
# List all registered filewatcher events
Get-EventSubscriber -Force

# to remove all of the watchers, run below. This is assuming you don't have any other 
# event subscriptions you want to keep live. If so, you probably already know what to do. =)
Get-EventSubscriber -Force | Unregister-Event -Force