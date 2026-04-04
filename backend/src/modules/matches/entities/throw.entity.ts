import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Leg } from './leg.entity';
import { User } from '../../users/entities/user.entity';

@Entity('throws')
export class Throw {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  leg_id: string;

  @Column({ type: 'uuid' })
  user_id: string;

  @Column({ type: 'int' })
  round_num: number;

  @Column({ type: 'int' })
  dart_num: number;

  @Column({ type: 'varchar', length: 10 })
  segment: string;

  @Column({ type: 'int' })
  score: number;

  @Column({ type: 'int' })
  remaining: number;

  @Column({ type: 'jsonb', nullable: true })
  dart_positions?: Array<{
    x: number;
    y: number;
    score?: number;
    label?: string;
  }>;

  @Column({ type: 'boolean', default: false })
  is_checkout: boolean;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @ManyToOne(() => Leg, (l) => l.throws, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'leg_id' })
  leg: Leg;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;
}
