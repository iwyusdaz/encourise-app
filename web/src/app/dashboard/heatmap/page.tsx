"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface ProgressEntry {
  device_uuid: string;
  topic_id: string;
  status: string;
  accuracy: number;
  level: number;
}

interface StudentName {
  device_uuid: string;
  name: string;
}

export default function HeatmapPage() {
  const [students, setStudents] = useState<StudentName[]>([]);
  const [progress, setProgress] = useState<ProgressEntry[]>([]);
  const [topics, setTopics] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchData();
  }, []);

  async function fetchData() {
    const [{ data: studentsData }, { data: progressData }] = await Promise.all([
      supabase.from("students_cloud").select("device_uuid, name").order("name"),
      supabase.from("topic_progress_cloud").select("*"),
    ]);

    if (studentsData) setStudents(studentsData);
    if (progressData) {
      setProgress(progressData);
      const uniqueTopics = [...new Set(progressData.map((p) => p.topic_id))].sort();
      setTopics(uniqueTopics);
    }
    setLoading(false);
  }

  function getCellColor(entry: ProgressEntry | undefined) {
    if (!entry) return "bg-secondary"; // not started — soft beige
    switch (entry.status) {
      case "mastered":
        return "bg-accent"; // mint
      case "in_progress":
        return "bg-[#EFD3C5]"; // peach sand
      case "flagged":
        return "bg-destructive"; // muted rose
      default:
        return "bg-secondary"; // soft beige
    }
  }

  function getCellLabel(entry: ProgressEntry | undefined) {
    if (!entry) return "—";
    return `${(entry.accuracy * 100).toFixed(0)}%`;
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border px-6 py-4 flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-foreground">Encourise</h1>
          <p className="text-sm text-muted-foreground">Weak Topic Heatmap</p>
        </div>
        <nav className="flex gap-4 text-sm">
          <Link href="/dashboard" className="text-muted-foreground hover:text-primary">
            Kelas
          </Link>
          <Link href="/dashboard/heatmap" className="font-medium text-primary">
            Heatmap
          </Link>
        </nav>
      </header>

      <main className="max-w-7xl mx-auto px-6 py-8">
        {/* Legend */}
        <div className="flex gap-6 mb-6 text-sm">
          <span className="flex items-center gap-2">
            <span className="w-4 h-4 rounded bg-accent inline-block" /> Mastered
          </span>
          <span className="flex items-center gap-2">
            <span className="w-4 h-4 rounded bg-[#EFD3C5] inline-block" /> In Progress
          </span>
          <span className="flex items-center gap-2">
            <span className="w-4 h-4 rounded bg-destructive inline-block" /> Flagged
          </span>
          <span className="flex items-center gap-2">
            <span className="w-4 h-4 rounded bg-secondary inline-block" /> Not Started
          </span>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Heatmap Topik per Siswa</CardTitle>
          </CardHeader>
          <CardContent className="overflow-x-auto">
            {loading ? (
              <p className="text-muted-foreground text-center py-8">Memuat data…</p>
            ) : students.length === 0 ? (
              <p className="text-muted-foreground text-center py-8">
                Belum ada data.
              </p>
            ) : (
              <table className="w-full text-sm">
                <thead>
                  <tr>
                    <th className="text-left py-2 px-3 font-medium text-foreground sticky left-0 bg-card z-10">
                      Siswa
                    </th>
                    {topics.map((topic) => (
                      <th
                        key={topic}
                        className="py-2 px-3 font-medium text-muted-foreground text-center min-w-[80px]"
                      >
                        {topic.replace(/_/g, " ")}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {students.map((student) => (
                    <tr key={student.device_uuid} className="border-t border-border">
                      <td className="py-2 px-3 font-medium sticky left-0 bg-card z-10">
                        <Link
                          href={`/dashboard/student/${student.device_uuid}`}
                          className="text-primary hover:underline"
                        >
                          {student.name}
                        </Link>
                      </td>
                      {topics.map((topic) => {
                        const entry = progress.find(
                          (p) =>
                            p.device_uuid === student.device_uuid &&
                            p.topic_id === topic
                        );
                        return (
                          <td key={topic} className="py-2 px-3 text-center">
                            <div
                              className={`inline-flex items-center justify-center w-14 h-8 rounded-md text-xs font-medium ${getCellColor(entry)}`}
                            >
                              {getCellLabel(entry)}
                            </div>
                          </td>
                        );
                      })}
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </CardContent>
        </Card>
      </main>
    </div>
  );
}
