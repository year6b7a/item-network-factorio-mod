# Item Network Factorio Mod

### Overview

This mod adds a new item transportation mechanic to move as many items as quickly as possible.

It does this by adding a new item called "Network Chest" which serves as an access point to a limitless shared inventory for the entire mod. Network Chests can give and take items to and from this shared inventory to quickly move large numbers of items.

This approach scales well for everything from a seldom-used mall to moving vast quantities of items.

For example, here's a mall powered entirely by network chests:
![Mall](/readme-pictures/mall.png)

And here's a single chest that can continuously transport 4 blue lanes of iron ore at once.
![Iron Transport](/readme-pictures/large-scale-iron.png)

This mod also adds a Network Loader which is just a normal loader for transporting full lanes of items in and out of network chests. Inserters also work with network chests but loaders often lead to cleaner designs.

Both Network Chests and Network Loaders are enabled without research and can be crafted without any items. These items might work well locked behind an endgame technology and require a ton of ingredients but for now it's more fun to have them available from the start.

Network chests give and take items randomly for equal distribution to all chests which means belt balancers are no longer needed.

### Target Audience

There is no doubt that this mod is cheating and defeats the purpose of many existing transportation mechanics like trains and logistic chests. If trains work well for you then you probably don't need this mod. This mod is instead intended for:

- Players who have already built large transportation layers and are ready for something simpler that scales better than trains.
- Players who want to rebuild small parts of their spaghetti base without rebuilding the entire factory.
- Players who want to play complex modpacks or scale factories without spending a lot of time pasting train blueprints.
- Players who want a simpler way to build outposts.

In short, this mod is for players who want a logistics solution that gets out of the way so they can focus on recipes and efficient factories.

### Configuring Network Chests

Network chests have a custom UI to configure requests that can be accessed by clicking on the chest.

Each chest has a list of requests. "Take" requests take items from the network and "Give" requests give items to the network.

![Adding a request](/readme-pictures/add-new-item.png)
![Chest with a request](/readme-pictures/chest-with-request.png)

Each request has a "limit" and "buffer" defined as follows:

- Take "item" from the network when there are more than "limit" items in the network and store "buffer" in this chest.
- Give "item" to the network when there are less than "limit" items in the network and store "buffer" in this chest.

This method of defining requests is easy to use but also allows for complex production loops with both custom input and output priorities.

For example, here's how to configure barrel supply for an entire factory. Barrels come from 2 types of sources, either an assembler that produces new barrels or from assemblers that empty fluids and produce a barrel as byproduct. Normally this is handled with a splitter that prioritizes input from un-barreling assemblers and similar behavior can be created with network chests.

![Barreling Configuration](/readme-pictures/barreling-loop.png)

The barrel assembler can give barrels to the network with a low limit of 10. The un-barreling assemblers can give barrels to the network with a higher limit of 100. The barreling assembler will make new barrels until there are 10 in the network, and from that point on un-barreling assemblers will give barrels with a higher priority to guarantee they don't back up.

A similar approach can be used on take requests to set priority. For example, it might be useful to prioritize coal going to the power plant while plastic and furnaces take goal with lower priority. This can be done by setting the coal network chest to take coal from the network with a limit of 0. Plastic can take coal only when there is more than 100 coal in the network. Coal mines will insert into the network up to 200 items to make sure items can be provided to both the power plant and plastic when there is enough coal.

### Copy Recipes from Assemblers

Recipes can be copied from assamblers just like requester logistic chests which makes it easy to build a mall.

### Integration with Personal Logistics

Every second, this mod tries to fulfull personal logistic requests from the item network and push trashed items into the network.

### Underlying Implementation

Network chests are implemented as a normal chest with 48 slots. Each of the chest's requests has a buffer size and filtered item slots are used to reserve space for that item. For example if the request buffers 51 coal, the mod will filter 2 chest slots for coal.

Since 2 slots of coal can hold 100 coal, the mod will set the chest bar to prevent inserting more coal if the number of coal equals or exceeds 51.

The mod won't let you add requests that buffer more than can be stored in the network chest.

This implementation makes it easy to buffer just one nuclear reactor at the mall or buffer 1000 iron ore for bulk transport.

### Fluids

Fluids cannot be directly transported through the network and instead need to be barreled.

### Performance

This mod is tuned to take about 1-2ms every tick and does a fixed amount of work on every tick. While this is a lot of time for each tick, this mod also does a lot of work to transport all items for an entire base. For larger bases this overhead is comparable to the render time for belts and trains.

Internally the mod maintains a circular buffer of every network chest. On every tick it randomly pops off 20 chests and updates their contents by either giving items to the network or taking items from the network.

Because this approach only scans a fixed number of chests per tick, chests will be scanned less frequently as the base scales up and more chests are built. It's sometimes necessary to increase the buffer and limit of high-throughput items like iron or copper and usually a buffer of 500-1000 items is enough to keep a full blue belt saturated.

### Play Testing

This mod has been tested in the following ways:

- Launched a rocket in vanilla Factorio with 10x science.
- Reached the "Quantum Age" in Exotic Industries (so far!).
- Unit tested the circular buffer implementation.

This is plenty of play time to test:

- The core chest management code correctly moves items without creating or destroying items.
- The mod shows no signs of slowing down with 1k network chests.
- The UI is easy enough to use to build lots of recipes.
- Moderately complex recipes with item loops and byproducts can be handled with buffer and limit mechanics.

### Contributing

Please submit issues on [the github repo](https://github.com/year6b7a/item-network-factorio-mod). Pull requests are welcome!