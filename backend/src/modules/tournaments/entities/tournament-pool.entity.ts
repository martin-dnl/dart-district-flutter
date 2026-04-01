import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
} from 'typeorm';
import { Tournament } from './tournament.entity';
import { TournamentPlayer } from './tournament-player.entity';
import { TournamentPoolStanding } from './tournament-pool-standing.entity';

@Entity('tournament_pools')
export class TournamentPool {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid')
  tournament_id: string;

  @Column({ type: 'varchar', length: 10 })
  pool_name: string;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @ManyToOne(() => Tournament, (tournament) => tournament.pools, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'tournament_id' })
  tournament: Tournament;

  @OneToMany(() => TournamentPlayer, (player) => player.pool)
  players: TournamentPlayer[];

  @OneToMany(() => TournamentPoolStanding, (standing) => standing.pool)
  standings: TournamentPoolStanding[];
}
