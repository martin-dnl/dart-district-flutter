import { OnGatewayConnection, OnGatewayDisconnect } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
export declare class MatchGateway implements OnGatewayConnection, OnGatewayDisconnect {
    server: Server;
    private readonly logger;
    handleConnection(client: Socket): void;
    handleDisconnect(client: Socket): void;
    handleJoinMatch(client: Socket, data: {
        match_id: string;
    }): {
        event: string;
        match_id: string;
    };
    handleLeaveMatch(client: Socket, data: {
        match_id: string;
    }): void;
    handleThrow(client: Socket, data: {
        match_id: string;
        leg_id: string;
        player_id: string;
        segment: string;
        score: number;
        remaining: number;
    }): void;
    handleScoreSync(client: Socket, data: {
        match_id: string;
        scores: Record<string, number>;
    }): void;
    emitMatchUpdate(matchId: string, payload: unknown): void;
    emitLegComplete(matchId: string, payload: unknown): void;
    emitMatchComplete(matchId: string, payload: unknown): void;
}
