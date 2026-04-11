import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';

import { User } from '../../users/entities/user.entity';

@Entity('social_posts')
@Index(['author_id', 'created_at'])
@Index(['created_at'])
export class SocialPost {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  author_id: string;

  @Column({ type: 'uuid' })
  match_id: string;

  @Column({ type: 'varchar', length: 16 })
  mode: string;

  @Column({ type: 'varchar', length: 32 })
  sets_score: string;

  @Column({ type: 'varchar', length: 32 })
  result_label: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'author_id' })
  author: User;
}
