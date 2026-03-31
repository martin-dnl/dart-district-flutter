import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Match } from './match.entity';
import { User } from '../../users/entities/user.entity';
import { Club } from '../../clubs/entities/club.entity';

@Entity('match_players')
export class MatchPlayer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  match_id: string;

  @Column({ type: 'uuid' })
  user_id: string;

  @Column({ type: 'uuid', nullable: true })
  club_id: string | null;

  @Column({ type: 'varchar', length: 10, default: 'home' })
  side: string;

  @Column({ type: 'int', nullable: true })
  final_score: number | null;

  @Column({ type: 'numeric', precision: 6, scale: 2, nullable: true })
  avg_score: number | null;

  @Column({ type: 'boolean', nullable: true })
  is_winner: boolean | null;

  @ManyToOne(() => Match, (m) => m.players, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'match_id' })
  match: Match;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @ManyToOne(() => Club, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'club_id' })
  club: Club;
}
