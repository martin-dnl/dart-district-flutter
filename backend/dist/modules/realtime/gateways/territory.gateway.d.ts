import { Server, Socket } from 'socket.io';
export declare class TerritoryGateway {
    server: Server;
    private normalizeTerritoryRoom;
    handleSubscribe(client: Socket, data: {
        territory_id?: string;
        code_iris?: string;
    }): {
        event: string;
        code_iris: string;
    };
    handleSubscribeMap(client: Socket): {
        event: string;
    };
    emitTerritoryUpdate(codeIris: string, payload: unknown): void;
    emitTerritoryStatusUpdated(codeIris: string, payload: unknown): void;
    emitTerritoryOwnerUpdated(codeIris: string, payload: unknown): void;
    emitDuelRequest(codeIris: string, payload: unknown): void;
    emitDuelAccepted(codeIris: string, payload: unknown): void;
    emitDuelCompleted(codeIris: string, payload: unknown): void;
}
