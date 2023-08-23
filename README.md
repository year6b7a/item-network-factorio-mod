# Item Network Factorio Mod

Do you have questions, comments or bugs? Stop by the [Discord server](https://discord.gg/aNPW2YWRcf), make a [Github Issue](https://github.com/year6b7a/item-network-factorio-mod/issues/) or start a discussion in the mod portal.

### Overview

This mod adds a new transportation mechanic to move items and fluids as quickly as possible.

It does this by adding Network Chests and Tanks which serve as an access points to a limitless shared inventory for the entire mod. Network Chests can give and take items to and from this shared inventory and Network Tanks move fluids.

This approach scales well for everything from a seldom-used mall to moving vast quantities of items.

This mod also adds a Network Loader which is just a normal loader for transporting full lanes of items in and out of network chests. Inserters also work with network chests but loaders often lead to cleaner designs.

Here's an example of moving 128 blue belts of copper ore where almost every belt is saturated. In addition to the 256 network chests in this picture, this world has 2084 network chests with half dedicated to moving copper and the other half moving other items.
![128 Belts of copper](/readme-pictures/2048-chest-test-consistency.png)

And here's a mall powered entirely by network chests:
![Mall](/readme-pictures/mall.png)

Both Network Chests and Network Loaders are enabled without research and can be crafted without any items. While it might be more fair to lock these items behind endgame research expensive ingredients, it's more fun to have them available from the start.

Network chests make belt balancers obsolete because they evenly distribute between producers and consumers.

### Target Audience

There is no doubt that this mod is cheating and defeats the purpose of many existing transportation mechanics like trains and bots. If trains work well for you then you probably don't need this mod. This mod is instead intended for:

- Players who have already built large transportation layers and are ready for something simpler that scales better than trains.
- Players who want to rebuild small parts of their spaghetti base without rebuilding the entire factory.
- Players who want to play complex modpacks or scale factories without spending a lot of time pasting train blueprints.
- Players who want a simpler way to build outposts.

In short, this mod is for players who want a logistics solution that gets out of the way so they can focus on recipes and efficient factories.

### Configuring Network Chests

Network chests have a custom UI to configure requests that can be accessed by clicking on the chest.

Each chest has a list of items where the chest either requests or provides each item.

![Adding a request](/readme-pictures/add-new-item.png)
![Chest with a request](/readme-pictures/chest-with-request.png)

Each request has a "limit" and "buffer" defined as follows:

- Provide `item` to the network when there are less than `limit` items in the network and store `buffer` items in this chest.
- Request `item` from the network when there are more than `limit` items in the network and store `buffer` items in this chest.

This method of defining requests is easy to use but also allows for complex production loops with both custom input and output priorities.

For example, here's how to prioritize sending coal to power generation. When there is more than 100 coal in the network it will be sent to plastic.

![Coal Prioritization](/readme-pictures/coal-priorities.png)

### Copy Recipes from Assemblers

Recipes can be copied from assamblers just like requester logistic chests which makes it easy to build a mall.

### Fluids

Fluids can be transported through the network using Network Tanks. These tanks are similar to Network Chests except they only transport 1 fluid at a time.

Network Tanks configured to Provide will try to push any fluids from the tank into the network up to the configured limit.

Network Tanks configured to Request will try to take the specified fluid at the specified temperature from the network.

As of 0.5.0, the network correctly handles fluids with different temperatures. Currently only whole-number temperatures are supported so please reach out if you have a use case for temperatures with decimals.

![Network Tank](/readme-pictures/network-tank.png)

### Network View

Pressing `Ctrl + Shift + N` will bring up the Network View to see items and fluids currently in the network.

In addition to displaying items and fluids in the network, there is also a "Shortages" tab that displays the number of unsatisfied item requests for the past 5 seconds.

![Network View window showing items and fluids in network](/readme-pictures/network-view.png)

### Logistics Integrations

- The mod will try to fulfill logistic and trash requests from players.
- The mod will try to fulfill logistic and trash requests from spidertrons.
- The mod will try to fulfill logistic requests from Requester and Buffer chests.
- The mod will try to give items to logistic networks that need items for construction.

Some of these integrations can be disabled in settings but please open an issue if you want to disable something else.

### Underlying Implementation

Network chests are implemented as a normal chest with 48 slots. Each of the chest's requests has a buffer size and filtered item slots are used to reserve space for that item. For example if the request buffers 51 coal, the mod will filter 2 chest slots for coal.

Since 2 slots of coal can hold 100 coal, the mod will set the chest bar to prevent inserting more coal if the number of coal equals or exceeds 51.

The mod won't let you add requests that buffer more than can be stored in the network chest.

This implementation makes it easy to buffer just one nuclear reactor at the mall or buffer 1000 iron ore for bulk transport.

### Performance

This mod is tuned to take about 1-3ms every tick and does a fixed amount of work on every tick. While this is a lot of time for each tick, this mod also does a lot of work to transport all items for an entire base. For larger bases this overhead is comparable to the render time for belts, trains and bots.

On the test world with 2048 network chests and 4096 loaders, the mod takes 2.5ms per tick which is about half the game update time on my computer.

Internally the mod maintains a FIFO queue of every Network Chest and Tank. On every tick it:

- Pops 20 entities off the front of the queue, updates the entities, and pushes them to the back of the queue.
- Randomly swaps a single entity to the front of the queue to slowly shuffle the update order.

Because this approach only scans a fixed number of chests per tick, chests will be scanned less frequently as the base scales up and more chests are built. It's sometimes necessary to increase the buffer and limit of high-throughput items like iron or copper and usually a buffer of 500-1000 items is enough to keep a full blue belt saturated.

Network chests have no trouble keeping blue belts saturated with less than 2K Network Chests in the map. However there have been reports that it is hard to saturate belts in larger factories with ~50K Network Chests. While improving mod performance is a key area of focus, in the short term it is currently recommended to keep the number of chests below 3K.

### Play Testing

This mod has been tested in the following ways:

- Launched a rocket in vanilla Factorio with 10x science.
- Reached the "Exotic Age" in Exotic Industries.
- Created a sandbox world with 2048 chests and 4096 loaders.
- Unit tested the circular buffer implementation.

This is plenty of play time to test:

- The core chest management code correctly moves items without creating or destroying items.
- The mod shows no signs of slowing down with 1k network chests.
- The UI is easy enough to use to build lots of recipes.
- Moderately complex recipes with item loops and byproducts can be handled with buffer and limit mechanics.

### Contributing

Please submit issues on [the github repo](https://github.com/year6b7a/item-network-factorio-mod). Pull requests are welcome!

### Similar Mods

The idea of teleporting items is definitely not new. Here is a short list of similar mods:

- [Crash-Site Logistics Center](https://mods.factorio.com/mod/Kux-LogisticsCenterCS)
- [TeleportProviderChest](https://mods.factorio.com/mod/TeleportProviderChest/faq)
- [ItemTeleportation](https://mods.factorio.com/mod/ItemTeleportation)
- [Subspace Storage](https://mods.factorio.com/mod/subspace_storage)
- [Bulk Teleporters](https://mods.factorio.com/mod/bulkteleport/faq)
- [Smart chest](https://mods.factorio.com/mod/smartchest)
- [Quantum Resource Distribution 2](https://mods.factorio.com/mod/QuantumResourceDistribution2)
- [Storage Energistics](https://mods.factorio.com/mod/storage_energistics)

While all these mods are related to teleporting items, they have different priorities and Item Network in particular has unique priorities that might make it a good fit.

- **Scale**: This mod is designed and tested to scale thousands of network chests and transport as many items as possible while being UPS friendly.
- **Complex Recipes**: Through limits, this mod can prioritize requesting and providing items to move items through complex recipe chains without requiring other coordination mechanisms like splitters or pumps.
- **Ease of Use**: This mod is designed to make it as easy as possible to move items without trying to make the mechanic balanced or fair. This mod is cheating but in an interesting way that can delight experienced players.
- **Compatibility**: This mod is designed to work with with all other mods without config changes.
