erlCluster
==========
 
 erlCluster is a distribution library, a proof of concept that enables your app to scale up joinning nodes to create a cluster in a transparent way, the main functionality is to create a key/value distributed storage where you are able to persist whatever data structure (pids, records...).

  This project is heavily inspired on riak core, in fact, it's a consecuence of riak core study, thinking
on reinventing the basis of the same wheel I've finally decide to create my own basic version. Starting point was to achieve some kind of dstributed get/set over the whole cluster, that enables to scale up adding more nodes, while the main app grows and consumes cluster resources.

 Using erlCluster enables you to scale up/down the number of nodes following your load needs,   
you need to know what data structure on your app needs to be global on your cluster, and let erlCluster to handle scalability. 

 An easy chat application, designed in a single node basis, spawns a process on each user session, so process registry stores user Pids. If a user A wants to send a message to user B, we need first to locate userB Pid from process registry and then pass the message. Is quite clear that process registry here is the point that needs to be decoupled and adapted to a multinode scenario, and that's what erlCluster does. 

How it works? 
=============

 It's based on a consistent hashing ring, using partitions as data destinations, where each partition has an owner node. When a new node joins the cluster, node claims its assigned cluster partitions, old node owners migrate its data to the new owner. Data manipulation is done using commands that are forwarded to the correct node and partition destination.

 erlCLuster implementation is focused on a flexible way, you are free to implement how cluster 
partition will work, declare and register your custom partition handler using erlCluster_partition behaviour ( erlCluster_partition_handler is the default one, take a look!). 

 That way you are able to use whatever data structure that you want to store, and how will be stored, just declare how to handle commands to manipulate them.

 A basic implementation is to use erlCluster with your own backend data store, whatever you want (redis, mnesia ...), as a result you have a Key/Value cluster database...yep!

Features
========

- Join/leave nodes to cluster, handling partitions
- Transparent command routing over the cluster
- handles all data types
- command execution and partition data structures are decleared using erlCluster_partition behaviour
- data integrity under node scale up/down
