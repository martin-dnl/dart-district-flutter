import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { TournamentPool } from './tournament-pool.entity';
import { User } from '../../users/entities/user.entity';

@Entity('tournament_pool_standings')
export class TournamentPoolStanding {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid')
  pool_id: string;

  @Column('uuid')
  user_id: string;

  @Column({ type: 'int', default: 0 })
  matches_played: number;

  @Column({ type: 'int', default: 0 })
  matches_won: number;

  @Column({ type: 'int', default: 0 })
  legs_won: number;

  @Column({ type: 'int', default: 0 })
  legs_lost: number;

  @Column({ type: 'int', default: 0 })
  points: number;

  @Column({ type: 'int', nullable: true })
  rank: number | null;

  @ManyToOne(() => TournamentPool, (pool) => pool.standings, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'pool_id' })
  pool: TournamentPool;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;
}
