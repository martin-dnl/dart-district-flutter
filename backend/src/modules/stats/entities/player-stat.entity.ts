import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  OneToOne,
  JoinColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

@Entity('player_stats')
export class PlayerStat {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', unique: true })
  user_id: string;

  @Column({ type: 'int', default: 0 })
  matches_played: number;

  @Column({ type: 'int', default: 0 })
  matches_won: number;

  @Column({ type: 'numeric', precision: 6, scale: 2, default: 0 })
  avg_score: number;

  @Column({ type: 'numeric', precision: 6, scale: 2, default: 0 })
  best_avg: number;

  @Column({ type: 'numeric', precision: 5, scale: 2, default: 0 })
  checkout_rate: number;

  @Column({ type: 'int', default: 0 })
  total_180s: number;

  @Column({ type: 'int', default: 0 })
  count_140_plus: number;

  @Column({ type: 'int', default: 0 })
  count_100_plus: number;

  @Column({ type: 'int', default: 0 })
  high_finish: number;

  @Column({ type: 'int', default: 0 })
  best_leg_darts: number;

  @Column({ type: 'numeric', precision: 5, scale: 2, default: 0 })
  precision_t20: number;

  @Column({ type: 'numeric', precision: 5, scale: 2, default: 0 })
  precision_t19: number;

  @Column({ type: 'numeric', precision: 5, scale: 2, default: 0 })
  precision_double: number;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;

  @OneToOne(() => User, (u) => u.stats, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;
}
