import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
} from 'typeorm';
import { Set } from './set.entity';
import { User } from '../../users/entities/user.entity';
import { Throw } from './throw.entity';

@Entity('legs')
export class Leg {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  set_id: string;

  @Column({ type: 'int' })
  leg_number: number;

  @Column({ type: 'uuid', nullable: true })
  winner_id: string | null;

  @Column({ type: 'int', default: 501 })
  starting_score: number;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @ManyToOne(() => Set, (s) => s.legs, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'set_id' })
  set: Set;

  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'winner_id' })
  winner: User;

  @OneToMany(() => Throw, (t) => t.leg)
  throws: Throw[];
}
