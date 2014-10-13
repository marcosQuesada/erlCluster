erlCluster [WIP]
================
 
 erlCluster is a distribution library, a proof of concept that enables your app to scale adding nodes, creating a cluster  in a transparent way .

  This project is heavily inspired on riak core, in fact, it's a consecuence of riak core study, thinking
on reinventing the basis of the same wheel I've finally decide to create my own basic version.

 To understand better what's this library objective, as example, thinking in riak database,  nodes are joined to create a cluster, allowing us to read and 
write data from each node in a transparent way, where routing part is done as a cluster feature. 
 Riak core has the same focus, example implementations give as a result a get/set over the 
whole cluster, that enables to scale up adding more nodes, while the main app grows and consumes cluster resources.

 To use erlCluster enables you to scale up/down the number of nodes following your load needs,   
you need to find what data structure on your app needs to be global on your cluster, and use erlCluster to handle scalability. 

  An easy chat application, created in a single node basis spawns a process on each user 
session, so process registry is the index book that points to each user process. If a user A wants to send a message to user B, app will ask its process registry to found user B Pid and then pass the message. So process registry is the point that needs to be decoupled and adapted to a multinode scenario, and it's what erlCluster does.

How it works? 
=============

 It's based on a consistent hashing ring, using partitions as data destinations,
where each partition has a node owner. When a new node joins the cluster, node claims its assigned cluster partitions, old node owners migrate his data to the new owner. Data manipulation is done using commands that are forwarded to the correct node and partition destination.

 erlCLuster implementation is focused on a flexible way, you are free to implement how cluster 
partition will work, declare and register your custom partition handler using erlCluster_partition behaviour ( erlCluster_partition_handler is the default one, take a look!). 

 That way you are able to use whatever data structure you want to store your data, where all
data types will be stored, and declare how to handle commands to manipulate them.

An easy erlCluster implementation is to add your own backend data store, whatever you want (redis, mnesia ...), as a result you have a Key/Value cluster database...yep! just basic features at this development point, but this is the idea. 

Features [WIP]
==============

- Join/leave nodes to cluster, handling partitions
- Transparent command routing over the cluster
- handles all data types
- command execution and partition data structures are decleared using erlCluster_partition behaviour
- data integrity under node scale up/down [WIP]
