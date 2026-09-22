import { RoomService } from '../server/rooms.mjs';
import { productionStore } from '../server/redis-store.mjs';
import { roomHTTP } from '../server/http.mjs';

let service;
export default roomHTTP(() => service ??= new RoomService(productionStore()), { trustProxy: true });
